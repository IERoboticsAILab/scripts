#!/bin/bash

# Define variables
GITHUB_REPO="https://github.com/IE-Robotics-Lab/scripts"
ANSIBLE_PACKAGES="setup/packages.yml"
ANSIBLE_PATH="setup/ansible.sh"
DNS_ENABLE_SCRIPT="https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/main/ubuntu_enable_local_dns.sh"
ANSIBLE_SSH="setup/services/ssh.yml"
LDAP_URI="ldap://10.205.10.3"
BASE_DN="dc=prometheus,dc=lab"
BIND_DN="cn=admin,dc=prometheus,dc=lab"
BIND_PW="didnotfight"
NFS_SERVER="10.205.10.3"
NFS_HOMES_EXPORT="/homes"

# Function to handle errors
die() {
    echo "$1" >&2
    exit 1
}

####### ANSIBLE SETUP #######
echo "Installing Ansible..."
curl -s https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/master/$ANSIBLE_PATH | bash
echo "Ansible installed!"

####### PACKAGES SETUP #######
echo "Running Ansible playbook for packages..."
ansible-pull -U "$GITHUB_REPO" -i "localhost," -c local -K "$ANSIBLE_PACKAGES" || die "Failed to run Ansible playbook for packages."

echo "Packages setup complete!"

####### DNS SETUP #######
echo "Testing local DNS resolution..."
ping prometheus -c 5 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Local DNS resolution is working!"
else
    echo "Local DNS resolution is not working. Would you like to set up a local DNS server? (y/n)"
    read -r answer
    if [ "$answer" == "y" ]; then
        echo "Enabling local DNS resolution..."
        curl -s "$DNS_ENABLE_SCRIPT" | bash || die "Failed to enable local DNS resolution."
        echo "Waiting for DNS to update..."
        sleep 5
        ping prometheus -c 5 >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Local DNS resolution enabled!"
        else
            echo "Local DNS resolution is still not working."
        fi
    else
        echo "Skipping DNS setup."
    fi
fi

####### SSH SETUP #######
echo "Running Ansible playbook for SSH setup..."
ansible-pull -U "$GITHUB_REPO" -i "localhost," -c local -K "$ANSIBLE_SSH" || die "Failed to configure SSH."
echo "SSH setup complete!"

####### LDAP CONFIGURATION #######
echo "Configuring LDAP authentication..."
sudo bash -c "cat > /etc/ldap.conf" <<EOL
URI $LDAP_URI
BASE $BASE_DN
BINDDN $BIND_DN
BINDPW $BIND_PW
EOL

sudo sed -i 's/^passwd:.*/passwd:         compat ldap/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*/group:          compat ldap/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*/shadow:         compat ldap/' /etc/nsswitch.conf

sudo systemctl restart autofs || die "Failed to restart autofs service."
sudo systemctl enable autofs || die "Failed to enable autofs service."

####### NFS CONFIGURATION #######
echo "Configuring NFS for home directories..."
if ! grep -qs "$NFS_SERVER:$NFS_HOMES_EXPORT" /etc/fstab; then
    sudo bash -c "echo '$NFS_SERVER:$NFS_HOMES_EXPORT /home nfs defaults 0 0' >> /etc/fstab"
    echo "NFS entry added to /etc/fstab."
fi

sudo mount -a || die "Failed to mount NFS directories."
echo "NFS directories mounted."

####### TESTING #######
echo "Testing LDAP and NFS configuration..."
getent passwd | grep ldap >/dev/null && echo "LDAP configuration successful." || echo "LDAP configuration failed."
ls /home >/dev/null && echo "NFS mount successful." || echo "NFS mount failed."

echo "Setup complete!"
