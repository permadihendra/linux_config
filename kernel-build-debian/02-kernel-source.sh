#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

echo "==> Searching available linux-source packages"
echo

# Query available linux-source packages
mapfile -t SOURCES < <(
  apt-cache search '^linux-source-[0-9]' \
  | awk '{print $1}' \
  | sed 's/linux-source-//' \
  | sort -V
)

if [ "${#SOURCES[@]}" -eq 0 ]; then
  echo "ERROR: No linux-source packages found."
  echo "Check that deb-src and main repositories are enabled."
  exit 1
fi

echo "Available linux-source versions:"
for v in "${SOURCES[@]}"; do
  echo "  - $v"
done
echo

read -rp "Enter linux-source version to install (press Enter for default): " KVER

if [ -n "$KVER" ]; then
  SRC_PKG="linux-source-$KVER"
else
  SRC_PKG="linux-source"
fi

echo
echo "==> Installing $SRC_PKG"
sudo apt update
sudo apt install -y "$SRC_PKG"

# ----------------------------------------
# Locate and extract linux-source tarball
# ----------------------------------------
cd "$WORKDIR"

tarball="$(ls linux-source-*.tar.* 2>/dev/null | head -n1)"
if [ -z "$tarball" ]; then
  echo "ERROR: linux-source tarball not found in $WORKDIR"
  exit 1
fi

srcdir="${tarball%.tar.*}"

echo "Found source tarball: $tarball"
echo "Source directory: $srcdir"

echo
echo "==> Extracting linux-source"
sudo rm -rf "$srcdir"
sudo tar -xf "$tarball"
sudo chown -R "$USER:$USER" "$srcdir"

mkdir -p "$KERNEL_OUT"
echo "$WORKDIR/$srcdir" > "$KERNEL_OUT/srcdir"

echo
echo "linux-source ready:"
echo "  Path: $WORKDIR/$srcdir"
echo "Next step: run ./03-config.sh"
