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
NFS_HOMES_EXPORT="/homes"
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

####### ANSIBLE SETUP #######
echo "Installing Ansible..."
curl -s https://raw.githubusercontent.com/IE-Robotics-Lab/scripts/master/$ANSIBLE_PATH | bash || die "Failed to install Ansible."
echo "Ansible installed!"

####### PACKAGES SETUP #######
echo "Installing necessary packages..."
apt-get update && apt-get install -y libnss-ldapd libpam-ldapd nscd nslcd autofs ansible || die "Failed to install necessary packages."

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
cat > /etc/auto.home <<EOF
* -fstype=nfs,rw $NFS_SERVER:$NFS_HOMES_EXPORT/&
EOF

# Restart autofs
systemctl restart autofs || die "Failed to restart autofs."

# Ensure NFS is also in /etc/fstab for fallback
if ! grep -qs "$NFS_SERVER:$NFS_HOMES_EXPORT" /etc/fstab; then
    echo "$NFS_SERVER:$NFS_HOMES_EXPORT /home nfs defaults 0 0" >> /etc/fstab
    echo "NFS entry added to /etc/fstab."
fi

sudo mount -a || die "Failed to mount NFS directories."

####### DYNAMIC PRIMARY GROUP CREATION #######
echo "Adding dynamic group creation for LDAP users..."

# Create a PAM script to assign the user's group dynamically
cat > /usr/local/bin/assign_primary_group.sh <<'EOF'
#!/bin/bash
USER="$PAM_USER"

if [ "$USER" ]; then
    if ! getent group "$USER" >/dev/null; then
        groupadd "$USER"
    fi

    # Update user's primary group if needed
    usermod -g "$USER" "$USER" >/dev/null 2>&1 || true
fi
EOF

chmod +x /usr/local/bin/assign_primary_group.sh

# Add PAM session module to execute the script
echo "session required pam_exec.so seteuid /usr/local/bin/assign_primary_group.sh" >> /etc/pam.d/common-session

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
