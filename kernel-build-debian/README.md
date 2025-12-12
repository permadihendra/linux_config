Below is a clear, production-ready **README.md** describing how to use *all* scripts in your tiny-kernel toolchain.
It is written for a Debian user building a minimized kernel using **linux-source from official Debian**, with a hardened minimal config.

If you need this delivered as an actual `README.md` file, tell me and I will generate it.

---

# README — Tiny Debian Kernel Build System

Minimized, Debian-compatible, reproducible kernel builds

This repository provides a set of scripts to generate a hardware-aware tiny kernel config and to build a minimized Debian kernel using official `linux-source-*` packages. It is optimized for:

* Minimal kernel size
* No debug symbols / no tracing
* Debian-compatible `.deb` packaging
* Clean upgrades and cleanup automation
* Reproducible builds using Debian resources

---

# 1. Overview of Scripts

## **1. generate-tiny-kernel-config.sh**

Purpose:
Generate a **tiny-base.config** based on detected hardware.
It reads system hardware using `lscpu`, `lsblk`, `lspci -nn`, and `lsusb`, then produces:

* `tiny-base.config` — a hardware-aware minimal kernel configuration

Run this **before building any kernel**.

---

## **2. build-tiny-debian-kernel.sh**

Purpose:
Build a Debian-compatible minimized kernel using:

* `linux-source-<version>` from Debian
* Hardware-aware tiny config
* Current running kernel config merged with tiny config
* Debug + tracing fully disabled
* Debian `.deb` packages built using `bindeb-pkg`
* Automatic installation
* Optional kernel retention policy

Outputs:

* Installed minimal kernel
* `.deb` packages stored in `~/kernel-debs`

---

## **3. cleanup-kernels.sh**

Purpose:
Automatically remove unused kernels, keeping only:

* 1 active kernel
* N previous kernels (configurable)

Avoids disk bloat caused by multiple kernel installs.

---

# 2. Usage Instructions

All scripts must be executed from **any directory**, but the default paths assume:

* Kernel source is extracted into `/usr/src`
* `.deb` packages stored in `~/kernel-debs`
* Your tiny config file is `./tiny-base.config`

You can safely run everything as a normal user; **the scripts will elevate privileges when required** using `sudo`.

---

# 3. Requirements

Before running anything, ensure:

```
sudo apt update
sudo apt install -y build-essential bc bison flex libncurses-dev \
libssl-dev libelf-dev dwarves fakeroot dpkg-dev git wget xz-utils
sudo apt build-dep -y linux || true
```

The build script automatically checks and installs missing dependencies.

---

# 4. Step-by-Step: Building a Tiny Debian Kernel

## **Step 1 — Generate the tiny minimal config**

Run:

```
./generate-tiny-kernel-config.sh
```

This script:

1. Reads your hardware:

   * CPU
   * Disk controllers
   * PCI devices
   * USB devices
2. Produces `tiny-base.config`

Verify the file:

```
cat tiny-base.config
```

---

## **Step 2 — Build the Debian kernel**

### Option A — Build with default Debian linux-source

```
./build-tiny-debian-kernel.sh
```

### Option B — Build a specific Debian linux-source version

Example:

```
./build-tiny-debian-kernel.sh 6.8
```

The script performs:

1. Install linux-source-VERSION
2. Extract kernel source to `/usr/src`
3. Copy current `/boot/config-$(uname -r)`
4. Merge tiny-base.config into it
5. Disable debug/tracing via `scripts/config`
6. `make olddefconfig`
7. Build Debian `.deb` packages using:

   ```
   fakeroot make -j<nproc-2> bindeb-pkg
   ```
8. Install the new kernel (`linux-image-*.deb`, `linux-headers-*.deb`)
9. Update initramfs + grub
10. Copy kernel packages to `~/kernel-debs`

Reboot into the new kernel:

```
sudo reboot
```

---

## **Step 3 — Optional: Cleanup old kernels**

After verifying the new kernel works, clean unused kernels:

```
./cleanup-kernels.sh
```

This script:

* Protects the running kernel
* Removes older kernels
* Removes matching headers

---

# 5. Where Should I Run These Scripts?

You can run all scripts from your **home directory**, such as:

```
~/tiny-kernel/
```

Recommended directory layout:

```
tiny-kernel/
│
├── generate-tiny-kernel-config.sh
├── tiny-base.config    (auto-generated)
├── build-tiny-debian-kernel.sh
└── cleanup-kernels.sh
```

You do **not** need to place scripts inside `/usr/src`.

Kernel source is automatically handled by Debian's `linux-source-*` package.

---

# 6. When Should I Use sudo?

The scripts automatically use `sudo` for actions requiring privilege:

* Installing packages
* Extracting kernel source to `/usr/src`
* Installing kernel `.deb` packages
* Updating grub/initramfs
* Removing old kernels

You do *not* need to run the scripts as root.

Run them as normal user:

```
chmod +x *.sh
./generate-tiny-kernel-config.sh
./build-tiny-debian-kernel.sh
./cleanup-kernels.sh
```

---

# 7. Expected Kernel Size After Build

Using this tiny kernel workflow, your installed kernel will typically be:

* **Smaller than stock Debian kernel**
* **No debug symbols**
* **No tracing/FTRACE**
* **Only hardware drivers from your system**
* **Reduced features / modules**

Typical size ranges:

* Debian stock kernel: 70–90 MB
* Tiny custom kernel: **18–35 MB**

(Actual size depends on filesystem, CPU architecture, and enabled modules.)

---

# 8. Troubleshooting

## Problem: build stops at `make olddefconfig`

Fix:
Your script must pipe empty input into the command:

```
yes "" | make olddefconfig
```

Our revised scripts already implement this.

## Problem: VM boots to initramfs

Causes:

* Missing storage driver
* Missing filesystem driver
* Missing VirtIO drivers
* initramfs not updated

Fix:
Regenerate config using tiny script + merge current config:

```
./generate-tiny-kernel-config.sh
./build-tiny-debian-kernel.sh
```

---

# 9. License

MIT License (optional)

---

If you want, I can also generate:

* A GitHub-ready repository
* A more detailed architecture document
* A systemd service for automatic kernel cleanup
* A CI-validated kernel build pipeline

Just tell me.
