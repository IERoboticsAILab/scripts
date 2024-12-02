
#!/bin/bash

# make a backup of the original files before modifying them
cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
cp /etc/pam.d/common-account /etc/pam.d/common-account.bak
cp /etc/pam.d/common-session /etc/pam.d/common-session.bak
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
cp /etc/auto.master /etc/auto.master.bak
cp /etc/auto.home /etc/auto.home.bak
cp /etc/sudoers /etc/sudoers.bak


# Install necessary packages
echo "Installing necessary packages..."
apt-get update && apt-get install -y libnss-ldapd libpam-ldapd nscd nslcd autofs
# automatically adds ldap to nsswitch.conf


# Variables
LDAP_URI="ldap://10.205.10.3/"
BASE_DN="dc=prometheus,dc=lab"
BIND_DN="cn=admin,dc=prometheus,dc=lab"
# prompt for the password -s can sometimes be an ilegal option
read -p "Enter the LDAP bind password: " BIND_PW
# check if the password is correct
ldapsearch -x -D $BIND_DN -w $BIND_PW -b $BASE_DN -H $LDAP_URI > /dev/null
if [ $? -ne 0 ]; then
    echo "Invalid password"
    exit 1
fi
NFS_SERVER="10.205.10.3"  # Replace with your NFS server IP or hostname
NFS_HOME="/homes"  # Replace with the NFS shared directory for home directories
PAST_ADMIN="lab"


# Configure nslcd for LDAP
echo "Configuring LDAP..."
cat > /etc/nslcd.conf <<EOF
uid nslcd
gid nslcd
uri $LDAP_URI
base $BASE_DN
binddn $BIND_DN
bindpw $BIND_PW
EOF

# PAM configuration for LDAP Authentication
echo "Configuring PAM for LDAP Authentication..."

sudo pam-auth-update

# Restart nslcd and nscd to apply changes
echo "Restarting services..."
systemctl restart nslcd
systemctl restart nscd


# make lab sudo
# check if lab exists in /etc/sudoers
grep -q "^lab" /etc/sudoers
if [ $? -ne 0 ]; then
    echo "lab ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

# also add "SUDOers" group to sudoers file if it is not already present
grep -q "^%SUDOers" /etc/sudoers
if [ $? -ne 0 ]; then
    echo "%SUDOers ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

# make lab the owner of /home if it is not already
if [ $(stat -c %U /home) != "lab" ]; then
    chown -R lab /home
fi

# create failsafe user
LOCAL_USER="failsafe"
LOCAL_PASS="oopsmybad"
# check if users exists or not

grep -q "^$LOCAL_USER" /etc/passwd
if [ $? -ne 0 ]; then
    echo "Creating failsafe user..."
    useradd -m $LOCAL_USER -d /var/local/$LOCAL_USER -s /bin/bash -p $(openssl passwd -1 $LOCAL_PASS) -G sudo
    chown -R $LOCAL_USER /var/local/$LOCAL_USER
fi

# remove past admin user if it exists
grep -q "^$PAST_ADMIN" /etc/passwd
if [ $? -eq 0 ]; then
    echo "Removing past admin user..."
    userdel -r $PAST_ADMIN
fi


# Configure autofs
echo "Configuring AutoFS..."
# if not already present, add the following line to /etc/auto.master
grep -q "^/home" /etc/auto.master
if [ $? -ne 0 ]; then
    echo "/home /etc/auto.home" >> /etc/auto.master
fi
if [ ! -f /etc/auto.home ]; then
    touch /etc/auto.home
    echo "* -fstype=nfs,rw $NFS_SERVER:$NFS_HOME/&" > /etc/auto.home
fi

# Restart autofs to apply the configuration
systemctl restart autofs

echo "Configuration complete. LDAP users should now be able to log in and access their NFS home directories."
