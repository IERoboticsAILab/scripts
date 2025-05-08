#!/bin/bash
apt-get install -y xrdp
mkdir /etc/polkit-1/localauthority/50-local.d
chown 755 /etc/polkit-1/localauthority/50-local.d

cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
chmod 644 /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
