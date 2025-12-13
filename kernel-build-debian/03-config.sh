#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

# ----------------------------
# Locate kernel source
# ----------------------------
srcdir=$(cat "$KERNEL_OUT/srcdir")
cd "$srcdir"

echo "==> Kernel source: $srcdir"
echo "==> Using tiny config: $TINY_CONFIG"
echo

# ----------------------------
# Step 1: Baseline config
# ----------------------------
BASE_CONFIG="/boot/config-$(uname -r)"
if [ ! -f "$BASE_CONFIG" ]; then
  echo "ERROR: Baseline config not found: $BASE_CONFIG"
  exit 1
fi

cp "$BASE_CONFIG" .config
echo "[OK] Copied baseline config from $BASE_CONFIG"

# ----------------------------
# Step 2: Merge tiny-base.config
# ----------------------------
MERGE_STATUS="FAILED"

if [ -x "scripts/kconfig/merge_config.sh" ]; then
  echo "Merging tiny-base.config into .config"
  if scripts/kconfig/merge_config.sh .config "$TINY_CONFIG"; then
    MERGE_STATUS="SUCCESS"
    echo "[OK] tiny-base.config merged successfully"
  else
    echo "[ERROR] merge_config.sh failed"
  fi
else
  echo "[WARN] merge_config.sh not found; skipping merge"
fi

echo "==> Forcing critical boot options"

# HARD REQUIREMENTS — DO NOT REMOVE
scripts/config --enable CONFIG_DEVTMPFS
scripts/config --enable CONFIG_DEVTMPFS_MOUNT
scripts/config --enable CONFIG_BLK_DEV_INITRD
scripts/config --enable CONFIG_TMPFS
scripts/config --enable CONFIG_EXT4_FS
scripts/config --enable CONFIG_EFI
scripts/config --enable CONFIG_EFI_STUB
scripts/config --enable CONFIG_MODULES

# ----------------------------
# Step 3: Disable debug options
# ----------------------------
if [ -x "scripts/config" ]; then
  echo "Disabling debug/tracing options"
  for opt in DEBUG_INFO DEBUG_KERNEL FTRACE; do
    scripts/config --disable "$opt" || true
  done
else
  echo "[WARN] scripts/config not available; debug options unchanged"
fi

# ----------------------------
# Step 4: Finalize config
# ----------------------------
unset MAKEFLAGS
set +e
echo "Running make olddefconfig (single-threaded)"
make -j1 olddefconfig
OLDDEF_RC=$?
set -e

OLDDEF_STATUS="FAILED"
if [ "$OLDDEF_RC" -eq 0 ]; then
  OLDDEF_STATUS="SUCCESS"
  echo "[OK] make olddefconfig completed successfully"
else
  echo "[ERROR] make olddefconfig failed (rc=$OLDDEF_RC)"
fi

# ----------------------------
# Step 5: Annotate .config (EOF comment)
# ----------------------------
{
  echo
  echo "# =================================================="
  echo "# Tiny Debian Kernel Config Metadata"
  echo "# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "# Kernel source: $srcdir"
  echo "# Baseline config: $BASE_CONFIG"
  echo "# Tiny config: $TINY_CONFIG"
  echo "# Merge tiny-base.config: $MERGE_STATUS"
  echo "# olddefconfig result: $OLDDEF_STATUS"
  echo "# =================================================="
} >> .config

# ----------------------------
# Step 6: Final checks
# ----------------------------
if [ "$MERGE_STATUS" != "SUCCESS" ] || [ "$OLDDEF_STATUS" != "SUCCESS" ]; then
  echo
  echo "ERROR: Kernel configuration incomplete."
  echo "Check merge or olddefconfig errors above."
  exit 1
fi

# Save final config snapshot
cp .config "$KERNEL_OUT/final.config"
echo
echo "[OK] Final kernel config saved to $KERNEL_OUT/final.config"
echo "03-config.sh completed successfully."
