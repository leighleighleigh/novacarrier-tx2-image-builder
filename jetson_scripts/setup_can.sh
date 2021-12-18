#!/bin/bash

### SETS UP THE TWO CAN INTERFACES
### ON A FRESH UBUNTU INSTALL
### Setup process taken from https://forums.developer.nvidia.com/t/how-to-use-can-on-jetson-tx2/54125/

END='\033[0m'
BOLD='\033[1m'
TXTWHITE='\033[97m'
BGRED='\033[48;5;9m'
ERROR=$BGRED$TXTWHITE$BOLD

# Check for sudo
if [ $EUID != 0 ]; then
    printf "${ERROR}Please run this script as root!${END}\n"
    printf "${ERROR}This is neccesary to apply the interface settings${END}\n"
    exit 1
fi

modprobe can
modprobe can_raw
modprobe mttcan

ip link set can0 type can bitrate 20000 berr-reporting on
ip link set up can0
ip link set can1 type can bitrate 20000 berr-reporting on
ip link set up can1

sudo apt-get install can-utils

# ip -details -statistics link show can0
# ip -details -statistics link show can1
