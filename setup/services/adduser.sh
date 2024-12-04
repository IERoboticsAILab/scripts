#!/bin/bash

cd /
sudo mkdir local
sudo chmod 755 /local
sudo chown root:root /local
sudo nano /etc/adduser.conf
sudo sed -i 's|DHOME=/home|DHOME=/local|' /etc/adduser.conf
sudo adduser --home /local/student --gecos "Student Guest" student