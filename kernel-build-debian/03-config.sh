#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

srcdir=$(cat "$KERNEL_OUT/srcdir")
cd "$srcdir"

cp /boot/config-$(uname -r) .config

scripts/kconfig/merge_config.sh .config "$TINY_CONFIG"

# Disable debug safely
for opt in DEBUG_INFO DEBUG_KERNEL FTRACE; do
  scripts/config --disable "$opt" || true
done

unset MAKEFLAGS
set +e
make -j1 olddefconfig
rc=$?
set -e

[ "$rc" -ne 0 ] && exit 1

cp .config "$KERNEL_OUT/final.config"
