#!/bin/bash

# Get location of this script. This is different to the current working directory, which could be anywhere!
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Load the environment variables
source ${SCRIPT_DIR}/install.env

# Check that the variables we need are set
# TODO

# Load the external utility scripts
source ${SCRIPT_DIR}/scripts/textutils.sh
source ${SCRIPT_DIR}/scripts/spinner.sh
source ${SCRIPT_DIR}/scripts/cmdutils.sh
# Load the setup scripts, which do all the hard work
source ${SCRIPT_DIR}/scripts/setup_functions.sh

title "Novacarrier: Kernel Compilation Tool"

prompt "[OPTIONAL] Would you like build the kernel Image now? This may take a while. ${BOLD}[y/N]${END} "

case "$REPLY" in
    "")
        ;;
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        ;;
esac

# Setup
start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig"
make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig
stop_spinner $?

start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 dtbs"
echo "Output being redirected to ${LOGFILE}"
# Build, there are different targets here
# make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 Image
# make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_prepare
# make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules
make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 dtbs | installlog
stop_spinner $?

# Copy image to the kernel image install dir for flash.sh
# $TEGRA_KERNEL_OUT/arch/arm64/boot/Image

# Copy dtbs to the kernel install dir for flash.sh
# $TEGRA_KERNEL_OUT/arch/arm64/boot/dts/

prompt "Would you like copy the freshly-build kernel device tree, to the install folder? ${BOLD}[Y/n]${END} "

case "$REPLY" in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "Quit. Kernel DTS built into ${TEGRA_KERNEL_OUT}"
        exit 1
        ;;
esac

start_spinner "Installing newly built DTS files..."
echo "Moving ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb to ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb-old"
mv ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb-old
echo "Copying ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts to ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb"
cp -R ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb
stop_spinner $?

echo "DONE!"

# Copy modules to the rootfs
# sudo make ARCH=arm64 O=$TEGRA_KERNEL_OUT modules_install INSTALL_MOD_PATH=<top>/Linux_for_Tegra/rootfs/
