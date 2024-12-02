#!/bin/bash

# Disable and stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Backup NetworkManager.conf
cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.bak

# Update DNS setting in NetworkManager.conf
if ! grep -q "dns=10.205.10.2" /etc/NetworkManager/NetworkManager.conf; then
    line_number=$(grep -n "\[main\]" /etc/NetworkManager/NetworkManager.conf | cut -d: -f1)
    sed -i "$line_number a dns=10.205.10.2" /etc/NetworkManager/NetworkManager.conf
fi

# Backup and remove resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.bak
rm -f /etc/resolv.conf

# Restart NetworkManager
sudo systemctl restart NetworkManager
