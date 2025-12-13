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

fail() {
  echo "❌ FAIL: $1"
  exit 1
}

pass() {
  echo "✅ PASS: $1"
}

check() {
  local opt="$1"
  grep -Eq "^$opt=y|^$opt=m" "$config"
}

check_y() {
  local opt="$1"
  grep -Eq "^$opt=y" "$config"
}

check_m_or_y() {
  local opt="$1"
  grep -Eq "^$opt=(y|m)" "$config"
}

echo "-- Architecture --"
check_y CONFIG_X86_64 || fail "CONFIG_X86_64 not enabled"
pass "x86_64 architecture"

echo
echo "-- Initramfs support --"
check_y CONFIG_BLK_DEV_INITRD || fail "Initramfs support missing"
pass "Initramfs enabled"

echo
echo "-- Module system --"
check_y CONFIG_MODULES || fail "Kernel modules disabled"
check_y CONFIG_MODULE_UNLOAD || fail "Module unload disabled"
pass "Module support OK"

echo
echo "-- Storage (block layer) --"
check_y CONFIG_BLOCK || fail "Block layer disabled"
check_m_or_y CONFIG_SCSI || fail "SCSI support missing"
check_m_or_y CONFIG_ATA || fail "ATA support missing"
pass "Block + storage core OK"

echo
echo "-- Filesystems (rootfs critical) --"
check_y CONFIG_EXT4_FS || fail "EXT4 filesystem missing"
check_y CONFIG_TMPFS || fail "TMPFS missing"
check_y CONFIG_DEVTMPFS || fail "DEVTMPFS missing"
check_y CONFIG_DEVTMPFS_MOUNT || fail "DEVTMPFS auto-mount missing"
pass "Root filesystem support OK"

echo
echo "-- Boot support --"
check_y CONFIG_EFI || fail "EFI support missing"
check_y CONFIG_EFI_STUB || fail "EFI stub missing"
pass "EFI boot support OK"

echo
echo "-- Compression --"
check_y CONFIG_KERNEL_GZIP || fail "Kernel gzip compression missing"
pass "Kernel compression OK"

echo
echo "-- Networking (minimal but required) --"
check_y CONFIG_NET || fail "Networking stack disabled"
check_m_or_y CONFIG_INET || fail "IPv4 missing"
pass "Basic networking OK"

echo
echo "==> Sanity check completed successfully"
echo "This kernel config is boot-viable."
