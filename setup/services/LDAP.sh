#!/bin/bash

# make a backup of the original files before modifying them
echo "[LDAP] Backing up original configuration files..."
cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.bak
cp /etc/pam.d/common-account /etc/pam.d/common-account.bak
cp /etc/pam.d/common-session /etc/pam.d/common-session.bak
cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
cp /etc/sudoers /etc/sudoers.bak


# Install necessary packages
echo "Installing necessary packages..."
apt-get update && apt-get install -y libnss-ldapd libpam-ldapd nscd nslcd autofs
# automatically adds ldap to nsswitch.conf

# prompt for the password
# (-s can sometimes be an ilegal option)
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

pam-auth-update || die "Failed to configure PAM for LDAP."

# Restart nslcd and nscd to apply changes
echo "[LDAP] Restarting services..."
systemctl restart nslcd nscd || die "Failed to restart LDAP services."

####### PAM CONFIGURATION #######
echo "[LDAP] Configuring PAM for LDAP Authentication..."
sed -i 's/^passwd:.*/passwd:         compat ldap/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:          compat ldap/' /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow:         compat ldap/' /etc/nsswitch.conf

# add "SUDOers" group to sudoers file (if it is not already present)
grep -q "^%SUDOers" /etc/sudoers
if [ $? -ne 0 ]; then
    echo "%SUDOers ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

# !!!! migrate to users.sh
# make lab sudo
# check if lab exists in /etc/sudoers
grep -q "^lab" /etc/sudoers
if [ $? -ne 0 ]; then
    echo "lab ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi


# make lab the owner of /home if it is not already
if [ $(stat -c %U /home) != "lab" ]; then
    chown -R lab /home
fi

# !!!! admin user (failsafe) should be created during ubuntu install...

# create failsafe user
#LOCAL_USER="failsafe"
#LOCAL_PASS="*******"


# check if users exists or not
#grep -q "^$LOCAL_USER" /etc/passwd
#if [ $? -ne 0 ]; then
#    echo "Creating failsafe user..."
#    useradd -m $LOCAL_USER -d /var/local/$LOCAL_USER -s /bin/bash -p $(openssl passwd -1 $LOCAL_PASS) -G sudo
#    chown -R $LOCAL_USER /var/local/$LOCAL_USER
#fi

# remove past admin user if it exists
#grep -q "^$PAST_ADMIN" /etc/passwd
#if [ $? -eq 0 ]; then
#    echo "Removing past admin user..."
#    userdel -r $PAST_ADMIN
#fi

echo "[LDAP] Configuration complete. LDAP users should now be able to log in and access their NFS home directories."
