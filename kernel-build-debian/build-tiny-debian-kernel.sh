#!/usr/bin/env bash
# build-tiny-debian-kernel.sh
# Build a minimized Debian-compatible kernel using tiny-base.config
#
# Usage:
#   ./build-tiny-debian-kernel.sh [KERNEL_VERSION]
# Example:
#   ./build-tiny-debian-kernel.sh 6.1
#
set -euo pipefail

# ----------------------------
# User-editable defaults
# ----------------------------
TINY_CONFIG="./tiny-base.config"    # path to the tiny config produced earlier
WORKDIR="/usr/src"                  # where linux-source tarball will be extracted
KEEP_DEBS_IN="${HOME%/}/kernel-debs" # place to copy resulting .deb files
KEEP_OLD_KERNELS=1                  # informational only; cleanup handled separately
EXTRA_DISABLES=(
  "DEBUG_INFO"
  "DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT"
  "DEBUG_KERNEL"
  "GDB_SCRIPTS"
  "FTRACE"
  "FUNCTION_TRACER"
  "FUNCTION_GRAPH_TRACER"
  "PERF_EVENTS"
  "LATENCYTOP"
)

# ----------------------------
# Derived variables
# ----------------------------
JOBS=$(( $(nproc) - 2 ))
if [ "$JOBS" -lt 1 ]; then JOBS=1; fi
export MAKEFLAGS="-j$JOBS"

KVER_ARG="${1:-}" # optional kernel source version like "6.1" or "6.6.14"

echo "Starting build-tiny-debian-kernel.sh"
echo " Jobs (nproc-2): $JOBS"
echo " Tiny config: $TINY_CONFIG"
if [ -n "$KVER_ARG" ]; then echo " Requested linux-source: $KVER_ARG"; fi
echo

# ----------------------------
# Sanity checks
# ----------------------------
if [ ! -f "$TINY_CONFIG" ]; then
  echo "ERROR: tiny-base config not found at $TINY_CONFIG"
  echo "Run generate-tiny-kernel-config.sh first or place your tiny-base.config here."
  exit 1
fi

# Ensure working directory exists
if [ ! -d "$WORKDIR" ]; then
  echo "WORKDIR ($WORKDIR) does not exist. Creating with sudo."
  sudo mkdir -p "$WORKDIR"
  sudo chown "$(id -u):$(id -g)" "$WORKDIR"
fi

# ----------------------------
# Step 0: Install build dependencies
# ----------------------------
echo "==> Installing build dependencies (requires sudo)"
sudo apt update
sudo apt install -y build-essential bc bison flex libncurses-dev libssl-dev libelf-dev dwarves \
  fakeroot dpkg-dev git wget xz-utils

# Install package build-deps for linux where possible (non-fatal)
echo "Attempting to install linux build-deps (may require apt sources)"
sudo apt build-dep -y linux || true

# ----------------------------
# Step 1: Install linux-source (Debian official) if needed
# ----------------------------
if [ -n "$KVER_ARG" ]; then
  srcpkg="linux-source-${KVER_ARG}"
  echo "Attempting to install package: $srcpkg (sudo apt install)"
  if ! sudo apt install -y "$srcpkg"; then
    echo "Warning: failed to install $srcpkg; falling back to default linux-source"
    sudo apt install -y linux-source
  fi
else
  echo "Installing default linux-source package (sudo apt install)"
  sudo apt install -y linux-source
fi

# ----------------------------
# Step 2: Locate and extract linux-source tarball
# ----------------------------
cd "$WORKDIR"
tarball="$(ls linux-source-*.tar.* 2>/dev/null | head -n1 || true)"
if [ -z "$tarball" ]; then
  echo "ERROR: No linux-source tarball found in $WORKDIR."
  echo "Ensure linux-source package is installed and provides linux-source-*.tar.xz in $WORKDIR."
  exit 1
fi

echo "Found source tarball: $tarball"
srcdir="$(basename "$tarball" | sed -E 's/\.tar\..*$//')"
# Clean previous source dir as root (if exists) to ensure a clean build
if [ -d "$srcdir" ]; then
  echo "Removing existing extracted directory $srcdir (clean rebuild)"
  sudo rm -rf "$srcdir"
fi

echo "Extracting $tarball to $WORKDIR (sudo)"
sudo tar -xf "$tarball"
# Ensure ownership of extracted dir to current user
sudo chown -R "$(id -u):$(id -g)" "$srcdir"
cd "$srcdir"
echo "Working in $(pwd)"
echo

# ----------------------------
# Step 3: Prepare .config
# ----------------------------
echo "==> Preparing configuration"

if [ -f "/boot/config-$(uname -r)" ]; then
  echo "Copying current running kernel config as baseline"
  cp /boot/config-$(uname -r) .config
else
  echo "No /boot/config-$(uname -r) found — creating a default .config"
  make defconfig
fi

# Merge tiny-base.config cleanly using merge_config.sh if present
if [ -x "scripts/kconfig/merge_config.sh" ]; then
  echo "Merging tiny config ($TINY_CONFIG) into .config"
  # merge_config.sh expects: base_config + other config(s)
  # Use it as non-privileged user (it's safe)
  scripts/kconfig/merge_config.sh .config "$TINY_CONFIG"
else
  echo "WARNING: merge_config.sh not found; copying tiny config over .config instead"
  cp "$TINY_CONFIG" .config
fi

# Ensure scripts/config is executable (some source packages supply it)
if [ -f "scripts/config" ]; then
  chmod +x scripts/config || true
fi

# Use scripts/config to disable debug/tracing options if available (non-fatal)
if [ -x "scripts/config" ]; then
  echo "Applying EXTRA_DISABLES via scripts/config"
  for opt in "${EXTRA_DISABLES[@]}"; do
    echo " - disabling $opt"
    scripts/config --disable "$opt" || true
  done
else
  echo "scripts/config not available; debug options may remain enabled."
fi

# ----------------------------
# Step 4: Non-interactive defaults (do NOT run under sudo)
# ----------------------------
echo "Running make olddefconfig (non-interactive)"
# Important: do NOT run under sudo — sudo breaks stdin and causes blocking.
# Use yes + redirect /dev/null to be robust in all cases.
yes "" | make olddefconfig KCONFIG_CONFIG=.config < /dev/null

echo "Configuration finalized."
echo

# ----------------------------
# Step 5: Export Debian packaging flags
# ----------------------------
# Avoid debug/debuginfo packages and limit parallelism
export DEB_BUILD_OPTIONS="parallel=${JOBS} nocheck noddebs"

# ----------------------------
# Step 6: Build Debian packages (fakeroot, non-privileged)
# ----------------------------
echo "==> Building Debian packages (this will take time)"
echo "Using $JOBS parallel jobs (MAKEFLAGS=$MAKEFLAGS)"

# Use bindeb-pkg if available; fallback to deb-pkg.
if make -v >/dev/null 2>&1 && grep -q -i "bindeb-pkg" Makefile 2>/dev/null; then
  echo "Using bindeb-pkg target"
  fakeroot make -j"$JOBS" bindeb-pkg
else
  echo "bindeb-pkg target not found; using deb-pkg instead"
  fakeroot make -j"$JOBS" deb-pkg
fi

# ----------------------------
# Step 7: Collect .deb files and install
# ----------------------------
cd ..
mkdir -p "$KEEP_DEBS_IN"
echo "Copying generated .deb packages to: $KEEP_DEBS_IN"
cp -v linux-image-*.deb linux-headers-*.deb "$KEEP_DEBS_IN" 2>/dev/null || true

echo
echo "==> Installing newly built kernel packages (requires sudo)"
if ls linux-image-*.deb 1>/dev/null 2>&1; then
  sudo dpkg -i linux-image-*.deb linux-headers-*.deb || {
    echo "dpkg install failed; check .deb files in $KEEP_DEBS_IN and logs."
    exit 1
  }
else
  echo "No linux-image-*.deb found in $(pwd). Check build logs."
  exit 1
fi

echo
echo "Updating initramfs and grub (sudo; no error if these commands fail)"
sudo update-initramfs -u -k all || true
sudo update-grub || true

# Copy .debs again to keep safe set (in case install moved them)
cp -v linux-image-*.deb linux-headers-*.deb "$KEEP_DEBS_IN" 2>/dev/null || true

echo
echo "Build & install finished. New packages copied to: $KEEP_DEBS_IN"
echo "Reboot to use the new kernel: sudo reboot"
echo

# Informational message about cleanup (script not removing kernels automatically here)
if [ "$KEEP_OLD_KERNELS" -ge 0 ]; then
  echo "Keeping $KEEP_OLD_KERNELS old kernel(s) (current + $KEEP_OLD_KERNELS previous(s) will remain)."
  echo "Use cleanup-kernels.sh to purge older kernels when you are satisfied."
fi

exit 0
