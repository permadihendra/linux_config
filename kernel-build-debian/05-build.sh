#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

srcdir=$(cat "$KERNEL_OUT/srcdir")
cd "$srcdir"

export DEB_BUILD_OPTIONS="parallel=$JOBS noddebs nocheck"
fakeroot make -j"$JOBS" bindeb-pkg
