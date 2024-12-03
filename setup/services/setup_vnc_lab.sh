#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Variables
VNC_USER="lab"  # Username
VNC_PASSWORD="vncvnc12"  # VNC password

# Switch to the user's home directory
USER_HOME="/home/$VNC_USER"
VNC_DIR="$USER_HOME/.vnc"
XSTARTUP="$VNC_DIR/xstartup"

echo "Setting up VNC server for user $VNC_USER..."

# Set up VNC password
echo "Setting VNC password..."
sudo -u $VNC_USER mkdir -p $VNC_DIR
echo $VNC_PASSWORD | vncpasswd -f > "$VNC_DIR/passwd"
sudo -u $VNC_USER chmod 600 "$VNC_DIR/passwd"

# Create the xstartup file
echo "Configuring xstartup file for GNOME..."
sudo -u $VNC_USER bash -c "cat > $XSTARTUP <<'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/gnome-session &
EOF"
sudo -u $VNC_USER chmod +x "$XSTARTUP"

# Create a systemd service file for VNC
echo "Creating systemd service for VNC..."
cat > /etc/systemd/system/vncserver@$VNC_USER.service <<EOF
[Unit]
Description=Start VNC server for $VNC_USER
After=syslog.target network.target

[Service]
Type=forking
User=$VNC_USER
Group=$VNC_USER
WorkingDirectory=$USER_HOME

PIDFile=$VNC_DIR/%H:%i.pid
ExecStart=/usr/bin/vncserver -localhost no :1
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable, and start the VNC service
echo "Reloading systemd and starting VNC service..."
systemctl daemon-reload
systemctl enable vncserver@$VNC_USER.service
systemctl start vncserver@$VNC_USER.service

# Configure UFW to allow VNC traffic
echo "Configuring UFW to allow VNC traffic on port 5901..."
ufw allow 5901/tcp

# Enable UFW if not already enabled
if [[ $(ufw status | grep -c "Status: inactive") -gt 0 ]]; then
  echo "Enabling UFW..."
  ufw enable
fi

# Final message
echo "VNC server setup complete. It will start automatically on boot."
echo "You can now connect to $VNC_USER's VNC server at <server-ip>:5901 with the password provided."
