#!/bin/bash
# Get location of this script. This is different to the current working directory, which could be anywhere!
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Load the environment variables
source ${SCRIPT_DIR}/install.env

# Load the external utility scripts
source ${SCRIPT_DIR}/scripts/textutils.sh
source ${SCRIPT_DIR}/scripts/spinner.sh
source ${SCRIPT_DIR}/scripts/cmdutils.sh
source ${SCRIPT_DIR}/scripts/build_functions.sh

# INSTALL good flag
INSTALLGOOD=1

# Check that the variables we need are set
if [[ -z "${INSTALLDIR}" ]]; then
    echo "Couldn't find \$INSTALLDIR value."
    INSTALLGOOD=0
fi

if [[ -z "${CROSS_COMPILE}" ]]; then
    echo "Couldn't find \$CROSS_COMPILE value."
    INSTALLGOOD=0
fi

if [[ -z "${LOCALVERSION}" ]]; then
    echo "Couldn't find \$LOCALVERSION value."
    INSTALLGOOD=0
fi

if [[ -z "${TEGRA_KERNEL_OUT}" ]]; then
    echo "Couldn't find \$TEGRA_KERNEL_OUT value."
    INSTALLGOOD=0
fi

# If the install was not good, quit
if [[ ${INSTALLGOOD} -eq 0 ]]; then
    echo "Please run setup.sh"
    exit 1
fi

# Load the external utility scripts
source ${SCRIPT_DIR}/scripts/textutils.sh
source ${SCRIPT_DIR}/scripts/spinner.sh
source ${SCRIPT_DIR}/scripts/cmdutils.sh
# Load the setup scripts, which do all the hard work
source ${SCRIPT_DIR}/scripts/setup_functions.sh

# Check that our source folder exists
if [ ! -d "${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9" ] 
then
    echo "Could not find kernel source folder."
    echo "Expected to find it at:"
    echo "\t${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9" 
    exit 1
fi


title "Novacarrier: Kernel DTB Compilation Tool"

setup_make

prompt "[OPTIONAL] Would you like build the kernel Device Tree Binaries now? ${BOLD}[Y/n]${END} "

case "$REPLY" in
    "")
        compile_dtbs
        ;;
    [yY][eE][sS]|[yY]) 
        compile_dtbs
        ;;
    *)
        ;;
esac

prompt "[OPTIONAL] Would you like install the compiled Device Tree Binaries, so they can be flashed? ${BOLD}[y/N]${END} "

case "$REPLY" in
    "")
        ;;
    [yY][eE][sS]|[yY]) 
        install_dtbs
        ;;
    *)
        ;;
esac

# Copy image to the kernel image install dir for flash.sh
# $TEGRA_KERNEL_OUT/arch/arm64/boot/Image

# Copy dtbs to the kernel install dir for flash.sh
# $TEGRA_KERNEL_OUT/arch/arm64/boot/dts/

echo "DONE!"

# Copy modules to the rootfs
# sudo make ARCH=arm64 O=$TEGRA_KERNEL_OUT modules_install INSTALL_MOD_PATH=<top>/Linux_for_Tegra/rootfs/
