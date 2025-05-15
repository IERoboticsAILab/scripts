#!/bin/bash

# Service variables moved to config file
GITHUB_REPO="https://github.com/IE-Robotics-Lab/scripts"
DNS_ENABLE_SCRIPT="https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/main/ubuntu_enable_local_dns.sh"
ADD_STUDENT_SCRIPT="https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/main/setup/adduser.sh"
ANSIBLE_SSH="setup/services/ssh.yml"

. $(dirname $0)/../common/useful.sh

# !!!! install each package set inside its own task script
# libnss-ldapd libpam-ldapd nscd nslcd installed in setup/services/LDAP.sh
# autofs installed in setup/services/nfs.sh
# ansible is being retired
apt install -y curl  || die "Failed to install curl."

assert

####### PACKAGES SETUP #######
# !!!! better reflect decissions in configuration (instead of interactive questions)
read -r -p "Would you like to install software packages? (y/n)" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then  
    software/essentials.sh
    software/python-packages.sh
    software/docker.sh    
    software/vnc.sh
    software/ros.sh  

    echo "Packages installed"
else
    echo "Skipping ROS and software installation..."
fi

assert

# !!!! script to setup SSH
# ansible-pull -U $GITHUB_REPO -i "localhost," -c local -K $ANSIBLE_SSH || die "Failed to run Ansible playbook."

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
# reuse services/ldap.sh script
./setup/services/ldap.sh


####### NFS CONFIGURATION #######
# reuse services/nfs.sh script
./setup/services/nfs.sh


# !!!! is it actually needed?
# Ensure home directory is owned by 'lab'
[ "$(stat -c %U /home)" != "$PAST_ADMIN" ] && chown -R lab /home

####### TESTING #######
echo "Testing LDAP and NFS configuration..."
getent passwd | grep ldap >/dev/null && echo "LDAP configuration successful." || echo "LDAP configuration failed."
ls /home >/dev/null && echo "NFS mount successful." || echo "NFS mount failed."

echo "Setup complete! LDAP users should now be able to log in and access their NFS home directories."

####### USER MANAGEMENT #######
# Add 'lab' to sudoers - users.sh

####### ADD STUDENT USER #######
read -r -p "Would you like to add a student user? (y/n)" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Running adduser.sh script..."
    curl -s "$ADD_STUDENT_SCRIPT" | bash || die "Failed to add student user."
else
    echo "Skipping student user creation."
fi

echo "Rebooting in 10 seconds..."
sleep 10
reboot
