#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

sudo apt update
sudo apt install -y \
  build-essential bc bison flex libncurses-dev \
  libssl-dev libelf-dev dwarves fakeroot \
  dpkg-dev git wget xz-utils

sudo apt build-dep -y linux || true
