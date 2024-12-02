GITHUB_REPO="https://github.com/IE-Robotics-Lab/scripts"
ANSIBLE_PACKAGES="setup/packages.yml"

####### ANSIBLE SETUP #######
echo "Installing Ansible..."
ANSIBLE_PATH="setup/ansible.sh"
curl -s https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/master/$ANSIBLE_PATH | bash
echo "Ansible installed!"

####### PACKAGES SETUP #######
echo "Running Ansible playbook for packages..."
ansible-pull -U $GITHUB_REPO -i "localhost," -c local -K $ANSIBLE_PACKAGES


####### DNS SETUP #######
ping prometheus -c 5
if [ $? -eq 0 ]; then
    echo "Local DNS resolution is working!"
else
    echo "Local DNS resolution is not working, do you want to setup a local DNS server? (y/n)"
    read answer
    if [ "$answer" == "y" ]; then
        echo "Enabling local DNS resolution..."
        DNS_ENABLE_SCRIPT="https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/main/ubuntu_enable_local_dns.sh"
        curl -s $DNS_ENABLE_SCRIPT | bash
        echo "Waiting for DNS to update..."
        # wait a bit for the DNS to update
        sleep 5
        echo "Local DNS resolution enabled!"
        # test it out by ping to colossus
        ping prometheus -c 5
        if [ $? -eq 0 ]; then
            echo "Local DNS resolution is working!"
        else
            echo "Local DNS resolution is STILL not working!"
        fi
    else
        echo "Skipping DNS setup..."
    fi
fi

####### SSH SETUP #######
ANSIBLE_SSH="setup/services/ssh.yml"
echo "Running Ansible playbook for SSH..."
ansible-pull -U $GITHUB_REPO -i "localhost," -c local -K $ANSIBLE_SSH
echo "Done!"


####### LDAP and NFS #####
echo "Running script for LDAP and NFS..."
LDAP_PATH="setup/services/LDAP.sh"
wget -q https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/main/$LDAP_PATH -O ldap.sh
chmod +x ldap.sh
sudo ./ldap.sh
