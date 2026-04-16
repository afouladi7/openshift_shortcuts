#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# 1. Interface Selection Menu
echo "Available network interfaces:"
interfaces=($(nmcli -t -f DEVICE device | grep -v "lo"))
PS3="Select the interface to bind dnsmasq to: "
select opt in "${interfaces[@]}"; do
    if [[ -n "$opt" ]]; then
        INTERFACE=$opt
        break
    else
        echo "Invalid selection."
    fi
done

# 2. Auto-detect IP and calculate Subnet Prefix
DETECTED_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
# Extract the first three octets (e.g., 192.168.1)
IP_PREFIX=$(echo $DETECTED_IP | cut -d. -f1-3)
DEFAULT_RANGE="$IP_PREFIX.100,$IP_PREFIX.200,12h"

# 3. DHCP Conditional with smart default
read -p "Do you want to enable DHCP? (y/n): " ENABLE_DHCP
if [[ "$ENABLE_DHCP" =~ ^[Yy]$ ]]; then
    read -p "Enter the DHCP range [$DEFAULT_RANGE]: " DHCP_RANGE
    DHCP_RANGE=${DHCP_RANGE:-$DEFAULT_RANGE}
fi

read -p "Enter router and registry IP [$DETECTED_IP]: " IP
IP=${IP:-$DETECTED_IP}

read -p "Enter the auth-zone (e.g., example.local): " AUTH_ZONE

# Install dnsmasq
echo "Installing dnsmasq..."
yum install -y dnsmasq firewalld

# Configure dnsmasq
echo "Configuring dnsmasq..."
DNSMASQ_CONF="/etc/dnsmasq.d/lab.conf"

cat <<EOF > $DNSMASQ_CONF
# Basic dnsmasq configuration
interface=$INTERFACE
bind-interfaces
domain=$AUTH_ZONE
local=/$AUTH_ZONE/
# Additional static DNS record
host-record=registry.$AUTH_ZONE,$IP
EOF

# Append DHCP specific settings only if selected
if [[ "$ENABLE_DHCP" =~ ^[Yy]$ ]]; then
    echo "dhcp-option=option:router,$IP" >> $DNSMASQ_CONF
    echo "dhcp-range=$DHCP_RANGE" >> $DNSMASQ_CONF
fi

# Start and enable services
echo "Starting services..."
systemctl enable --now dnsmasq
systemctl enable --now firewalld

# Configure firewall
echo "Configuring firewall rules..."
firewall-cmd --add-service=dns --permanent
firewall-cmd --add-interface=$INTERFACE --zone=trusted --permanent

if [[ "$ENABLE_DHCP" =~ ^[Yy]$ ]]; then
    firewall-cmd --add-service=dhcp --permanent
fi

firewall-cmd --reload
systemctl restart dnsmasq

# Summary Output
echo ""
echo "------------------------------------------------"
echo "Setup Complete!"
echo "Interface:    $INTERFACE"
echo "Registry IP:  $IP"
if [[ "$ENABLE_DHCP" =~ ^[Yy]$ ]]; then
    echo "DHCP Range:   $DHCP_RANGE"
fi
echo "Static Host:  registry.$AUTH_ZONE -> $IP"
echo "------------------------------------------------"
