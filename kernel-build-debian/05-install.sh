#!/usr/bin/env bash
set -euo pipefail
source ./00-env.sh

cd "$WORKDIR"

sudo dpkg -i linux-image-*.deb linux-headers-*.deb
sudo update-initramfs -u -k all
sudo update-grub
