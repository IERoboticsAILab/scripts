#!/bin/bash

ros_version="humble"

common/add-ubuntu-repo.sh universe
apt-get update
apt-get install -y curl

echo "Adding ROS repo key..."
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# !!!! use common/add-ubuntu-repo.sh
echo "Adding ROS repo..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

apt-get update
# ROS recommends to upgrade OS before installation
apt-get upgrade -y

apt-get install -y ros-${version}-desktop

# ROS-Base Install (Bare Bones): Communication libraries, message packages, command line tools. No GUI tools.
# apt-get install -y ros-humble-ros-base
# Development tools: Compilers and other tools to build ROS packages
# apt-get install -y ros-dev-tools

echo "Installing additional ROS dependencies..."
apt-get install -y python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential

# /etc/ros/rosdep/sources.list.d/20-default.list
echo "Initializing rosdep..."
rosdep init

echo "Updating rosdep..."
rosdep update

echo "Updating ~/.bashrc to load ROS setup.bash..."
if ! grep "source /opt/ros/noetic/setup.bash" ~/.bashrc ; then
    echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc;
fi
