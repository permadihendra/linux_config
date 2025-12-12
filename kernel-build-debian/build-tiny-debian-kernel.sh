#!/usr/bin/env bash
# Build a minimized Debian-compatible kernel using tiny-base.config
# - Uses official Debian linux-source (installs if missing)
# - Merges tiny-base.config with current running config
# - Disables debug symbols/tracing to minimize size
# - Builds Debian .deb packages (bindeb-pkg) and installs them
#
# Usage:
#   ./build-tiny-debian-kernel.sh [KERNEL_VERSION]
# If KERNEL_VERSION is provided, the script will attempt to install linux-source-<KERNEL_VERSION>.
# If not provided, it installs the default linux-source package.

set -euo pipefail

# User-editable defaults
TINY_CONFIG="./tiny-base.config"          # path to the tiny config produced earlier
WORKDIR="/usr/src"                        # where linux-source will be extracted
KEEP_DEBS_IN="$HOME/kernel-debs"          # where .deb files will be copied for safekeeping
KEEP_OLD_KERNELS=1                        # keep 1 older kernel (so current + previous remain)
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

# Derived
JOBS=$(( $(nproc) - 2 ))
if [ "$JOBS" -lt 1 ]; then JOBS=1; fi

KVER_ARG="${1:-}"      # optional kernel source version like "6.1" or "6.6.14"
echo "Build script starting. Jobs: $JOBS. Tiny config: $TINY_CONFIG"
echo "Kernel version arg: '${KVER_ARG}'"

# ensure tiny config exists
if [ ! -f "$TINY_CONFIG" ]; then
  echo "ERROR: tiny-base config not found at $TINY_CONFIG"
  echo "Run generate-tiny-kernel-config.sh first or place your tiny-base.config here."
  exit 1
fi

# Step 0: Install build deps (and linux-source)
echo
echo "==> Installing build dependencies"
sudo apt update
sudo apt install -y build-essential bc bison flex libncurses-dev libssl-dev libelf-dev dwarves \
  fakeroot dpkg-dev git wget xz-utils

# ensure build-deps for linux are installed
sudo apt build-dep -y linux || true

# Install linux-source package (either specific or default)
if [ -n "$KVER_ARG" ]; then
  srcpkg="linux-source-${KVER_ARG}"
  echo "Attempting to install $srcpkg"
  if ! sudo apt install -y "$srcpkg"; then
    echo "Failed to install package $srcpkg via apt. Try installing default linux-source instead."
    sudo apt install -y linux-source
  fi
else
  echo "Installing default linux-source package"
  sudo apt install -y linux-source
fi

# find the linux-source tarball
cd "$WORKDIR"
tarball="$(ls linux-source-*.tar.* 2>/dev/null | head -n1 || true)"
if [ -z "$tarball" ]; then
  echo "No linux-source tarball found in $WORKDIR. Please install linux-source or specify a correct WORKDIR."
  exit 1
fi

echo "Found source tarball: $tarball"
# extract to a new directory
srcdir="$(basename "$tarball" | sed -E 's/\.tar\..*$//')"
if [ -d "$srcdir" ]; then
  echo "Removing existing extracted directory $srcdir (clean rebuild)."
  sudo rm -rf "$srcdir"
fi

sudo tar -xf "$tarball"
cd "$srcdir"
echo "Working in $(pwd)"

# Step: prepare .config
echo
echo "==> Preparing configuration"
if [ -f "/boot/config-$(uname -r)" ]; then
  echo "Copying current running kernel config as baseline"
  cp /boot/config-$(uname -r) .config
else
  echo "No /boot/config-$(uname -r) found — creating a default .config"
  make defconfig
fi

# Merge tiny-base.config into .config using merge_config.sh (part of kernel source)
if [ -x "scripts/kconfig/merge_config.sh" ]; then
  echo "Merging tiny config ($TINY_CONFIG) into current config"
  # merge_config.sh expects paths; keep it local
  scripts/kconfig/merge_config.sh .config "$TINY_CONFIG"
else
  echo "WARNING: merge_config.sh not found; copying tiny config over .config instead"
  cp "$TINY_CONFIG" .config
fi

# Disable debug/tracing via scripts/config if available
if [ -x "scripts/config" ]; then
  echo "Applying EXTRA_DISABLES via scripts/config"
  for opt in "${EXTRA_DISABLES[@]}"; do
    echo " - disabling $opt"
    scripts/config --disable "$opt" || true
  done
else
  echo "scripts/config not available; debug options may remain enabled."
fi

# Ensure defaults for new symbols
echo "Running make olddefconfig to adapt to new kernel source"
yes "" | make olddefconfig

# Step: control packaging flags
# Use noddebs to avoid creating debug .ddeb packages; nocheck to skip tests.
export DEB_BUILD_OPTIONS="parallel=${JOBS} nocheck noddebs"

# Step: Build Debian packages (bindeb-pkg creates binary .deb)
echo
echo "==> Building Debian packages (this will take time)"
echo "Using $JOBS parallel jobs"
# Use fakeroot and bindeb-pkg target (bindeb-pkg creates .deb without source .dsc)
# bindeb-pkg is available in upstream make targets for building debs. If not, fallback to deb-pkg.
if make -v >/dev/null 2>&1 && grep -q -i "bindeb-pkg" Makefile 2>/dev/null; then
  echo "Using bindeb-pkg target"
  fakeroot make -j"$JOBS" bindeb-pkg
else
  echo "bindeb-pkg target not found; using deb-pkg instead"
  fakeroot make -j"$JOBS" deb-pkg
fi

# .deb files should be in parent directory
cd ..
mkdir -p "$KEEP_DEBS_IN"
echo "Copying .deb packages to $KEEP_DEBS_IN"
cp -v linux-image-*.deb linux-headers-*.deb "$KEEP_DEBS_IN" 2>/dev/null || true

echo
echo "==> Installing newly built kernel packages"
sudo dpkg -i linux-image-*.deb linux-headers-*.deb || {
  echo "dpkg install failed; check .deb files in $KEEP_DEBS_IN and logs."
  exit 1
}

echo
echo "Updating initramfs and grub (if not auto-run)"
sudo update-initramfs -u -k all || true
sudo update-grub || true

echo
echo "Build & install finished. New packages copied to: $KEEP_DEBS_IN"
echo "Reboot to use the new kernel: sudo reboot"

# Optional: keep a simple retention policy: remove all but current & previous
if [ "$KEEP_OLD_KERNELS" -ge 0 ]; then
  echo
  echo "Keeping $KEEP_OLD_KERNELS old kernel(s) (current + $KEEP_OLD_KERNELS previous(s) will remain)."
  echo "To purge older kernels later, run cleanup-kernels.sh included separately."
fi

exit 0
