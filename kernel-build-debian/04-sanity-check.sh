#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

srcdir=$(cat "$KERNEL_OUT/srcdir")
config="$srcdir/.config"

if [ ! -f "$config" ]; then
  echo "ERROR: .config not found at $config"
  exit 1
fi

echo "==> Kernel configuration sanity check"
echo "Config: $config"
echo

FAILURES=0

pass() {
  echo "✅ PASS: $1"
}

fail() {
  echo "❌ FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

check_y() {
  grep -Eq "^$1=y" "$config"
}

check_m_or_y() {
  grep -Eq "^$1=(y|m)" "$config"
}

# --------------------------------------------------
echo "-- Architecture --"
check_y CONFIG_X86_64 \
  && pass "x86_64 architecture" \
  || fail "CONFIG_X86_64 not enabled"

# --------------------------------------------------
echo
echo "-- Initramfs support --"
check_y CONFIG_BLK_DEV_INITRD \
  && pass "Initramfs enabled" \
  || fail "CONFIG_BLK_DEV_INITRD missing"

# --------------------------------------------------
echo
echo "-- Module system --"
check_y CONFIG_MODULES \
  && pass "Module system enabled" \
  || fail "CONFIG_MODULES disabled"

check_y CONFIG_MODULE_UNLOAD \
  && pass "Module unload supported" \
  || fail "CONFIG_MODULE_UNLOAD missing"

# --------------------------------------------------
echo
echo "-- Storage (block layer) --"
check_y CONFIG_BLOCK \
  && pass "Block layer enabled" \
  || fail "CONFIG_BLOCK missing"

check_m_or_y CONFIG_SCSI \
  && pass "SCSI core present" \
  || fail "CONFIG_SCSI missing"

check_m_or_y CONFIG_ATA \
  && pass "ATA support present" \
  || fail "CONFIG_ATA missing"

# --------------------------------------------------
echo
echo "-- Filesystems (rootfs critical) --"
check_y CONFIG_EXT4_FS \
  && pass "EXT4 filesystem enabled" \
  || fail "CONFIG_EXT4_FS missing"

check_y CONFIG_TMPFS \
  && pass "TMPFS enabled" \
  || fail "CONFIG_TMPFS missing"

check_y CONFIG_DEVTMPFS \
  && pass "DEVTMPFS enabled" \
  || fail "CONFIG_DEVTMPFS missing"

check_y CONFIG_DEVTMPFS_MOUNT \
  && pass "DEVTMPFS auto-mount enabled" \
  || fail "CONFIG_DEVTMPFS_MOUNT missing"

# --------------------------------------------------
echo
echo "-- Boot support --"
check_y CONFIG_EFI \
  && pass "EFI support enabled" \
  || fail "CONFIG_EFI missing"

check_y CONFIG_EFI_STUB \
  && pass "EFI stub enabled" \
  || fail "CONFIG_EFI_STUB missing"

# --------------------------------------------------
echo
echo "-- Compression --"

if grep -Eq "^CONFIG_KERNEL_(GZIP|XZ|ZSTD|LZ4|LZO)=y" "$config"; then
  comp=$(grep -E "^CONFIG_KERNEL_(GZIP|XZ|ZSTD|LZ4|LZO)=y" "$config" \
         | sed 's/CONFIG_KERNEL_//' | sed 's/=y//')
  pass "Kernel compression enabled ($comp)"
else
  fail "No kernel compression method enabled"
fi

# --------------------------------------------------
echo
echo "-- Networking (minimal) --"
check_y CONFIG_NET \
  && pass "Networking stack enabled" \
  || fail "CONFIG_NET missing"

check_m_or_y CONFIG_INET \
  && pass "IPv4 stack present" \
  || fail "CONFIG_INET missing"

# --------------------------------------------------
echo
echo "==> Sanity check summary"

if [ "$FAILURES" -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED"
  echo "Kernel configuration is boot-viable."
  exit 0
else
  echo "❌ $FAILURES check(s) FAILED"
  echo "Fix the above issues before running the build step."
  exit 1
fi
