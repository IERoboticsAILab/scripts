#!/bin/bash

# Define variables
GITHUB_REPO="https://github.com/IE-Robotics-Lab/scripts"
ANSIBLE_PACKAGES="setup/packages.yml"
ANSIBLE_PATH="setup/ansible.sh"
DNS_ENABLE_SCRIPT="https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/main/ubuntu_enable_local_dns.sh"
ANSIBLE_SSH="setup/services/ssh.yml"
LDAP_URI="ldap://10.205.10.3/"
BASE_DN="dc=prometheus,dc=lab"
BIND_DN="cn=admin,dc=prometheus,dc=lab"
NFS_SERVER="10.205.10.3"
NFS_HOME="/homes"
PAST_ADMIN="admin"
LOCAL_USER="failsafe"
LOCAL_PASS="oopsmybad"

# Function to handle errors
die() {
    echo "$1" >&2
    exit 1
}

# Backup original configuration files
echo "Backing up original configuration files..."
cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
cp /etc/pam.d/common-account /etc/pam.d/common-account.bak
cp /etc/pam.d/common-session /etc/pam.d/common-session.bak
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
cp /etc/auto.master /etc/auto.master.bak
cp /etc/auto.home /etc/auto.home.bak
cp /etc/sudoers /etc/sudoers.bak

sudo apt install curl libnss-ldapd libpam-ldapd nscd nslcd autofs -y || die "Failed to install curl."

####### PACKAGES SETUP #######
read -r -p "Would you like to install Ansible packages? (y/n)" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    ####### ROS SETUP #######
    echo "Installing ROS..."
    sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' || die "Failed to add ROS repository."
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add - || die "Failed to add ROS key."
    sudo apt update

    ####### ANSIBLE SETUP #######
    echo "Installing Ansible..."
    ansible-pull -U $GITHUB_REPO -i "localhost," -c local -K $ANSIBLE_PACKAGES || die "Failed to install Ansible."
    ansible-pull -U $GITHUB_REPO -i "localhost," -c local -K $ANSIBLE_SSH || die "Failed to run Ansible playbook."
    echo "Ansible installed!"
else
    echo "Skipping ROS and Ansible installation."
fi

####### DNS SETUP #######
echo "Testing local DNS resolution..."
ping prometheus -c 5 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    read -r -p "Local DNS resolution is not working. Would you like to set up a local DNS server? (y/n)" response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Enabling local DNS resolution..."
        curl -s "$DNS_ENABLE_SCRIPT" | bash || die "Failed to enable local DNS resolution."
        echo "Waiting for DNS to update..."
        sleep 5
    else
        echo "Skipping DNS setup."
    fi
fi

####### LDAP CONFIGURATION #######
echo "Configuring LDAP..."
read -p "Enter the LDAP bind password: " BIND_PW
ldapsearch -x -D "$BIND_DN" -w "$BIND_PW" -b "$BASE_DN" -H "$LDAP_URI" > /dev/null || die "Invalid LDAP credentials."

cat > /etc/nslcd.conf <<EOF
uid nslcd
gid nslcd
uri $LDAP_URI
base $BASE_DN
binddn $BIND_DN
bindpw $BIND_PW
EOF

sudo pam-auth-update || die "Failed to configure PAM for LDAP."

# Restart services
echo "Restarting LDAP services..."
systemctl restart nslcd nscd || die "Failed to restart LDAP services."

####### PAM CONFIGURATION #######
echo "Configuring PAM for LDAP Authentication..."
sudo sed -i 's/^passwd:.*/passwd:         compat ldap/' /etc/nsswitch.conf
sudo sed -i 's/^group:.*/group:          compat ldap/' /etc/nsswitch.conf
sudo sed -i 's/^shadow:.*/shadow:         compat ldap/' /etc/nsswitch.conf

####### NFS CONFIGURATION #######
echo "Configuring AutoFS and NFS for home directories..."
grep -q "^/home" /etc/auto.master || echo "/home /etc/auto.home" >> /etc/auto.master
echo "* -fstype=nfs,rw $NFS_SERVER:$NFS_HOME/&" > /etc/auto.home
systemctl restart autofs || die "Failed to restart autofs."

# Ensure home directory is owned by 'lab'
[ "$(stat -c %U /home)" != "$PAST_ADMIN" ] && chown -R lab /home

####### USER MANAGEMENT #######
# Add 'lab' to sudoers
grep -q "^lab" /etc/sudoers || echo "lab ALL=(ALL:ALL) ALL" >> /etc/sudoers
grep -q "^%SUDOers" /etc/sudoers || echo "%SUDOers ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Create failsafe user if not exists
grep -q "^$LOCAL_USER" /etc/passwd || useradd -m $LOCAL_USER -d /var/local/$LOCAL_USER -s /bin/bash -p "$(openssl passwd -1 $LOCAL_PASS)" -G sudo

# Remove past admin user
grep -q "^$PAST_ADMIN" /etc/passwd && userdel -r $PAST_ADMIN

####### TESTING #######
echo "Testing LDAP and NFS configuration..."
getent passwd | grep ldap >/dev/null && echo "LDAP configuration successful." || echo "LDAP configuration failed."
ls /home >/dev/null && echo "NFS mount successful." || echo "NFS mount failed."

echo "Setup complete! LDAP users should now be able to log in and access their NFS home directories."
