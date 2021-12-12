#!/bin/bash

# Get location of this script. This is different to the current working directory, which could be anywhere!
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Setup the environment flags
INSTALLDIR=${SCRIPT_DIR}/local/

BSPFILEDONE="${INSTALLDIR}/.extracted_bsp"
ROOTFSFILEDONE="${INSTALLDIR}/.extracted_rootfs"
LOGFILE=${INSTALLDIR}/install.log
ENVFILE=${INSTALLDIR}/install.env

# Load the external utility scripts
source ${SCRIPT_DIR}/scripts/textutils.sh
source ${SCRIPT_DIR}/scripts/spinner.sh
source ${SCRIPT_DIR}/scripts/cmdutils.sh
# Load the setup scripts, which do all the hard work
source ${SCRIPT_DIR}/scripts/setup_functions.sh

### Store our current install environment variables
setup_envfile
# Write variables to it
echo "export SCRIPT_DIR=${SCRIPT_DIR}" >> ${ENVFILE}
echo "export INSTALLDIR=${INSTALLDIR}" >> ${ENVFILE}

### Clear the logfile
echo "" > ${LOGFILE}
# Logging command.Adds timestamp, Appends to logfile and hides output.
shopt -s expand_aliases
alias installlog="tee -a ${LOGFILE} >/dev/null"

# Custom nova text
title "Novacarrier: Build Environment Setup Tool"

# Check for sudo
if [ $EUID != 0 ]; then
    printf "${ERROR}This script requires sudo!${END}\n"
    printf "${ERROR}This is neccesary to use QEMU.${END}\n"
    exit 1
fi

# Prompt for the install thing
echo ""

prompt "This script will install to ${BOLD}${INSTALLDIR}.${END}\nThis will require ~30GB of installation space.\nContinue? ${BOLD}[Y/n]${END} "

case "$REPLY" in
    "")
        ;;
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "Quitting."
        exit 1
        ;;
esac

### DIRECTORY SETUP
start_spinner "mkdir ${INSTALLDIR} && cd ${INSTALLDIR}"
mkdir -p $INSTALLDIR && cd $INSTALLDIR
stop_spinner $?

# Start log
echo "START NOVACARRIER KERNEL DEV SETUP LOG" > ${LOGFILE}

### These functions are defined in scripts/setup_functions.sh
get_archives
extract_archives
apply_binaries

# Prompt for the install thing
prompt "Would you like setup the kernel source files, and install the compilation toolchain? ${BOLD}[Y/n]${END} "
case "$REPLY" in
    "")
        ;;
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "Quit. Base install complete!"
        exit 1
        ;;
esac

setup_kernel_sources

echo "${BOLD}Kernel source ready for compilation!${END}"
echo "You may now run ${BUILD}build.sh${END}"