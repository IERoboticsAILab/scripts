#!/bin/bash

# Script to sync home directory permissions and ownership based on LDAP configuration

# Function to apply ownership and permissions
sync_directory() {
    local dir=$1
    local user=$2
    local group=$3
    local permissions=$4

    echo "Updating $dir..."
    sudo chown -R "$user":"$group" "$dir"
    sudo chmod "$permissions" "$dir"
}

# Sync directories based on the given mapping
#  sync_directory /home/cgomez cgomez 1000000 755
# sync_directory /home/edu edu 1000000 755
# sync_directory /home/forfaly forfaly 1000000 755
# sync_directory /home/gringo gringo 1000000 755
# sync_directory /home/haxybaxy haxybaxy 1000000 755
# sync_directory /home/luis luis 1000000 755
# sync_directory /home/paches paches 1000000 755
# sync_directory /home/rodrigo rodrigo 1000000 755
# sync_directory /home/Suzan suzan 1000000 755
# sync_directory /home/velocitatem velocitatem 1000000 755
sync_directory /home/lab lab 1000000 755


# Verify the changes
echo "Verification of changes:"
ls -la /home
