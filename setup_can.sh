#!/bin/bash

### SETS UP THE TWO CAN INTERFACES
### ON A FRESH UBUNTU INSTALL
### Setup process taken from https://forums.developer.nvidia.com/t/how-to-use-can-on-jetson-tx2/54125/2

INFO='\033[0;32;1m'
END='\033[0m'
BOLD='\033[1m'
TITLE='\033[0;36;1m'

TXTWHITE='\033[97m'
BGORANGE='\033[48;5;208m'
BGRED='\033[48;5;9m'
NOVA=$BGORANGE$TXTWHITE$BOLD
ERROR=$BGRED$TXTWHITE$BOLD

function title () {
    echo 
    # txtlen + 1 for centering
    txtlen=$(expr ${#1} + 1)
    printf "${NOVA}"
    printf -- "-%.0s" $(seq 0 $txtlen)
    printf "${END}\n"

    printf "${NOVA}"
    printf " ${1^^} "
    printf "${END}\n"

    printf "${NOVA}"
    printf -- "-%.0s" $(seq 0 $txtlen)
    printf "${END}\n"
    echo
}

# Reponse is stored into $REPLY
function boldprompt () {
    printf "${BOLD}$1${END}"
    read -r
}
# Response is in $REPLY. Formatting is cleared.
function prompt () {
    printf "$1${END}"
    read -r
}

# Custom nova text
title "Novacarrier: CAN Interface Setup"

# Check for root
if [[ "$(whoami)" != root ]]; then
  printf "${ERROR}Please run this script as root!${END}\n"
  printf "${ERROR}This is neccesary to apply the interface settings${END}\n"
  exit 1
fi

modprobe can
modprobe can_raw
modprobe mttcan

ip link set can0 type can bitrate 500000 dbitrate 2000000 berr-reporting on fd on
ip link set up can0
ip link set can1 type can bitrate 500000 dbitrate 2000000 berr-reporting on fd on
ip link set up can1