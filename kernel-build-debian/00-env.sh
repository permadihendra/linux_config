#!/usr/bin/env bash
set -euo pipefail

export WORKDIR="/usr/src"
export KERNEL_OUT="$HOME/kernel-build"
export KEEP_DEBS="$HOME/kernel-debs"
export TINY_CONFIG="$(readlink -f ./tiny-base.config)"

export JOBS=$(( $(nproc) - 2 ))
[ "$JOBS" -lt 1 ] && JOBS=1

echo "Env loaded:"
echo "  WORKDIR=$WORKDIR"
echo "  JOBS=$JOBS"
echo "  TINY_CONFIG=$TINY_CONFIG"
