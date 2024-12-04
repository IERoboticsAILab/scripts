# Create the /local directory and set permissions
sudo mkdir /local
sudo chmod 755 /local
sudo chown root:root /local

# Modify the adduser default configuration to change the home directory base
sudo sed -i 's|DHOME=/home|DHOME=/local|' /etc/adduser.conf

# Add the student user with a specified home directory and GECOS information
sudo adduser --home /local/student --gecos "Student Guest" student <<EOF

EOF

# Retrieve the hostname
HOSTNAME=$(hostname)

# Set the student's password to the hostname
echo "student:$HOSTNAME" | sudo chpasswd

# Output a message indicating the password has been set
echo "Password for user 'student' has been set to the hostname: $HOSTNAME"
