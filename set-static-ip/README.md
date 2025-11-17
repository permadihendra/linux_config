# 🚀 Debian Static IP Auto-Configuration Script

This script automatically configures a **static IPv4 address** on
Debian.

## 📄 File: `set-static-ip.sh`

```bash
#!/bin/bash
IP="$1"
GATEWAY="$2"
DNS="$3"
if [ -z "$IP" ] || [ -z "$GATEWAY" ] || [ -z "$DNS" ]; then
    echo "Usage: sudo bash set-static-ip.sh <IP> <GATEWAY> <DNS>"
    exit 1
fi
IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
cp /etc/network/interfaces /etc/network/interfaces.bak_$(date +%s)
cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback
allow-hotplug $IFACE
iface $IFACE inet static
    address $IP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers $DNS
EOF
systemctl restart networking
```

## 🧪 Usage Example

```bash
sudo bash set-static-ip.sh 192.168.7.2 192.168.7.1 8.8.8.8
```
