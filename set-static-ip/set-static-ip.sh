#!/bin/bash

# Script: set-static-ip.sh
# Usage: sudo bash set-static-ip.sh <IP> <GATEWAY> <DNS>

IP="$1"
GATEWAY="$2"
DNS="$3"

# Validate input
if [ -z "$IP" ] || [ -z "$GATEWAY" ] || [ -z "$DNS" ]; then
    echo "Usage: sudo bash set-static-ip.sh <IP> <GATEWAY> <DNS>"
    exit 1
fi

# Detect primary network interface (non-loopback)
IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')

echo "Detected interface: $IFACE"

# Backup existing configuration
cp /etc/network/interfaces /etc/network/interfaces.bak_$(date +%s)

# Write new static IP configuration
cat <<EOF >/etc/network/interfaces
# This file is managed by set-static-ip.sh

auto lo
iface lo inet loopback

allow-hotplug $IFACE
iface $IFACE inet static
    address $IP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers $DNS
EOF

echo "✓ Static IP configuration applied:"
echo "  IP:      $IP"
echo "  Gateway: $GATEWAY"
echo "  DNS:     $DNS"
echo ""
echo "Restarting networking service..."

systemctl restart networking

echo "✓ Networking restarted."
echo "Run: ip a   to verify new IP"
