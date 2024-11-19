#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Prompt user for input
read -p "Enter the DHCP range (e.g., 192.168.1.100,192.168.1.200,12h): " DHCP_RANGE
read -p "Enter the auth-zone (e.g., example.local): " AUTH_ZONE
read -p "Enter the network interface to bind dnsmasq to (e.g., eth0): " INTERFACE

# Install dnsmasq
echo "Installing dnsmasq..."
dnf install -y dnsmasq

# Configure dnsmasq
echo "Configuring dnsmasq..."
DNSMASQ_CONF="/etc/dnsmasq.d/lab.conf"
cat <<EOF > $DNSMASQ_CONF
# Basic dnsmasq configuration
interface=$INTERFACE
bind-interfaces

domain=$AUTH_ZONE
dhcp-range=$DHCP_RANGE
local=/$AUTH_ZONE/

# Additional static DNS record
host-record=registry.$AUTH_ZONE,192.168.1.10
EOF

# Restart and enable dnsmasq
echo "Restarting dnsmasq..."
systemctl restart dnsmasq
systemctl enable dnsmasq

# Configure firewall
echo "Configuring firewall rules..."
firewall-cmd --add-service=dns --permanent
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --add-interface=$INTERFACE --zone=trusted --permanent
firewall-cmd --reload

echo "dnsmasq installation and configuration complete."
echo "DHCP range: $DHCP_RANGE"
echo "Auth-zone: $AUTH_ZONE"
echo "Interface: $INTERFACE"
echo "Static record added for registry.$AUTH_ZONE."
