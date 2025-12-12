#!/bin/bash
set -e

echo "=== Collecting Hardware Information ==="

CPU_INFO="$(lscpu)"
DISK_INFO="$(lsblk -o NAME,MODEL)"
PCI_INFO="$(lspci -nn)"
USB_INFO="$(lsusb)"

echo "Saving hardware info to hw-info.txt"
{
    echo "===== CPU INFO ====="
    echo "$CPU_INFO"
    echo
    echo "===== DISK INFO ====="
    echo "$DISK_INFO"
    echo
    echo "===== PCI INFO ====="
    echo "$PCI_INFO"
    echo
    echo "===== USB INFO ====="
    echo "$USB_INFO"
} > hw-info.txt

echo "Hardware information saved."

# Optional: print a short summary
echo
echo "=== Summary ==="
echo "CPU Model: $(echo "$CPU_INFO" | grep 'Model name')"
echo "Disk Models Detected:"
echo "$DISK_INFO"
echo
echo "Key PCI Devices:"
echo "$PCI_INFO" | grep -E 'VGA|Network|Audio|USB'
echo

# Create tiny base kernel config file
echo "=== Writing tiny-base.config ==="

cat > tiny-base.config << 'EOF'
# Architecture
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_X86=y
CONFIG_GENERIC_CPU=y

# Initramfs
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_RD_XZ=y
CONFIG_KALLSYMS=n
CONFIG_KALLSYMS_ALL=n

# General kernel
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n
CONFIG_GDB_SCRIPTS=n

# Filesystems
CONFIG_EXT4_FS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y

# Disable heavy filesystems
CONFIG_XFS_FS=n
CONFIG_BTRFS_FS=n
CONFIG_NFS_FS=n
CONFIG_CIFS=n
CONFIG_ISO9660_FS=n
CONFIG_UDF_FS=n

# Storage drivers
CONFIG_ATA=y
CONFIG_SATA_AHCI=y
CONFIG_NVME_CORE=y
CONFIG_BLK_DEV_SD=y

# CPU Power management
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND=y
CONFIG_CPU_IDLE=y

# Network core
CONFIG_NET=y
CONFIG_INET=y
CONFIG_IPV6=y
CONFIG_NETFILTER=n

# USB
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_UHCI_HCD=y
CONFIG_USB_STORAGE=y

# Bluetooth (off)
CONFIG_BT=n
CONFIG_BT_HCIBTUSB=n

# Sound
CONFIG_SND=y
CONFIG_SND_HDA_INTEL=y

# Graphics (baseline)
CONFIG_DRM=y
CONFIG_FRAMEBUFFER_CONSOLE=y
EOF

echo "tiny-base.config generated."

echo
echo "NEXT STEPS:"
echo "1. Send me hw-info.txt so I can generate your hardware-specific tiny .config."
echo "2. Then you merge config:"
echo "   scripts/kconfig/merge_config.sh .config tiny-base.config"
echo "3. Then:"
echo "   make olddefconfig"
echo
echo "Done."
