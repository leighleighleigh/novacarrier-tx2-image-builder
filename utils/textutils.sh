#!/bin/bash

# Rainbow time
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

# Response is in $REPLY. Formatting is cleared.
function prompt () {
    printf "${NOVA}PROMPT:${END} "
    printf "$1${END}"
    read -r
}