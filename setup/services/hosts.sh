#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# Check if a new hostname is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <new-hostname>"
  exit 1
fi

NEW_HOSTNAME=$1

# Update /etc/hostname
echo "$NEW_HOSTNAME" > /etc/hostname

# Update /etc/hosts
sed -i "s/^127\.0\.1\.1\s.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts

# Apply the new hostname
hostnamectl set-hostname "$NEW_HOSTNAME"

# Confirm the change
echo "Hostname successfully changed to: $NEW_HOSTNAME"