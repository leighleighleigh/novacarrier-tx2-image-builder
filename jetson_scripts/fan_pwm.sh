#!/bin/bash

# This script is pretty simple.
# Input argument is just the fan pwm, from 0 to 255.
# Apparently setting it to '0' will put it into automatic mode.

END='\033[0m'
BOLD='\033[1m'
TXTWHITE='\033[97m'
BGRED='\033[48;5;9m'
ERROR=$BGRED$TXTWHITE$BOLD

# Check for sudo
if [ $EUID != 0 ]; then
    printf "${BOLD}Please run this script as root!${END}\n"
    printf "This is neccesary to write to the fan device.\n"
    exit 1
fi

function printhelp()
{
   # Display Help
   echo "Syntax: ./fan_pwm.sh <pwm>"
   echo "example:"
   echo "./fan_pwm.sh 0"
   echo "./fan_pwm.sh 255"
   echo
}

# Check for input args
if [ "$#" -ne 1 ]; then
    printhelp
else
    PWM=$1
    echo "Setting fan PWM to ${PWM}"
    echo ${PWM} > /sys/devices/pwm-fan/target_pwm 
fi