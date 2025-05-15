#!/bin/bash
apt-get update
apt-get install -y vim git curl wget net-tools python3 python3-pip

# Update OS pip to latest
# !!!! is last version of pip really needed?
pip3 install --upgrade pip
