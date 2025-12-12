#!/bin/bash
set -e

echo "=== Collecting Hardware Information ==="

CPU_INFO="$(lscpu)"
DISK_INFO="$(lsblk -o NAME,MODEL)"
PCI_INFO="$(lspci -nn)"
USB_INFO="$(lsusb)"

echo "Hardware detection complete."
echo

########################################
# CPU OPTIMIZATION
########################################

if echo "$CPU_INFO" | grep -qi "Intel"; then
    CPU_TYPE="intel"
elif echo "$CPU_INFO" | grep -qi "AMD"; then
    CPU_TYPE="amd"
else
    CPU_TYPE="generic"
fi

########################################
# GPU DRIVER DETECTION
########################################

GPU_DRIVER=""

if echo "$PCI_INFO" | grep -qi "VGA"; then
    if echo "$PCI_INFO" | grep -qi "Intel"; then
        GPU_DRIVER="CONFIG_DRM_I915=y"
    elif echo "$PCI_INFO" | grep -qi "AMD"; then
        GPU_DRIVER="CONFIG_DRM_AMDGPU=y"
    elif echo "$PCI_INFO" | grep -qi "NVIDIA"; then
        GPU_DRIVER="CONFIG_DRM_NOUVEAU=y"
    else
        GPU_DRIVER="CONFIG_DRM_SIMPLEDRM=y"
    fi
else
    GPU_DRIVER="CONFIG_DRM_SIMPLEDRM=y"
fi

########################################
# STORAGE DRIVER DETECTION
########################################

STORAGE_OPTS=""
if echo "$DISK_INFO" | grep -qi "NVMe"; then
    STORAGE_OPTS+="CONFIG_NVME_CORE=y\nCONFIG_BLK_DEV_NVME=y\n"
fi

if echo "$DISK_INFO" | grep -qi "SSD\|HDD\|SATA"; then
    STORAGE_OPTS+="CONFIG_ATA=y\nCONFIG_SATA_AHCI=y\n"
fi

if echo "$DISK_INFO" | grep -qi "MMC\|eMMC"; then
    STORAGE_OPTS+="CONFIG_MMC=y\nCONFIG_MMC_BLOCK=y\nCONFIG_MMC_SDHCI=y\n"
fi

########################################
# NETWORK DRIVER DETECTION
########################################

NET_DRIVER=""

if echo "$PCI_INFO" | grep -qi "Realtek"; then
    NET_DRIVER="CONFIG_R8169=y"
fi

if echo "$PCI_INFO" | grep -qi "Intel.*Wireless"; then
    NET_DRIVER="CONFIG_IWLWIFI=y"
fi

if echo "$PCI_INFO" | grep -qi "Qualcomm.*Atheros"; then
    NET_DRIVER="CONFIG_ATH9K=y"
fi

if [ -z "$NET_DRIVER" ]; then
    NET_DRIVER="CONFIG_USB_NET_DRIVERS=y"
fi

########################################
# AUDIO DETECTION
########################################

AUDIO_DRIVER="CONFIG_SND_HDA_INTEL=y"
if ! echo "$PCI_INFO" | grep -qi "Audio"; then
    AUDIO_DRIVER="CONFIG_SND_HDA_INTEL=n"
fi

########################################
# USB SUPPORT (always minimal)
########################################

USB_OPTS="
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_UHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_STORAGE=y
CONFIG_USB_HID=y
"

########################################
# BUILD TINY CONFIG
########################################

echo "Generating tiny-base.config..."

cat > tiny-base.config <<EOF
#
# Auto-generated Tiny Debian Kernel Config
#

# Core architecture
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_X86=y

# CPU Optimization
EOF

# CPU
if [ "$CPU_TYPE" = "intel" ]; then
    echo "CONFIG_MCORE2=y" >> tiny-base.config
elif [ "$CPU_TYPE" = "amd" ]; then
    echo "CONFIG_MZEN=y" >> tiny-base.config
else
    echo "CONFIG_GENERIC_CPU=y" >> tiny-base.config
fi

cat >> tiny-base.config <<EOF

# Initramfs support
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_RD_XZ=y

# Debug disabled
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n

# Filesystems
CONFIG_EXT4_FS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y

# Disable heavy FS
CONFIG_XFS_FS=n
CONFIG_BTRFS_FS=n
CONFIG_NFS_FS=n
CONFIG_UDF_FS=n

# Storage
$STORAGE_OPTS

# GPU
$GPU_DRIVER

# Network
$NET_DRIVER

# USB
$USB_OPTS

# Audio
$AUDIO_DRIVER

# Console framebuffer
CONFIG_FRAMEBUFFER_CONSOLE=y

# Modules support
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y

EOF

echo "tiny-base.config created."
echo
echo "=== NEXT STEPS ==="
echo "1. Merge into official Debian kernel source:"
echo "   cp tiny-base.config linux-source/"
echo "2. Build the kernel"
echo "   execute build-tiny-debian-kernel.sh"
echo "Have fun build your kernel."
