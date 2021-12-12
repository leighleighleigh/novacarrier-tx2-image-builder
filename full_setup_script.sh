#!/bin/bash

# Get location of this script. This is different to the current working directory, which could be anywhere!
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Setup the environment flags
INSTALLDIR=${SCRIPT_DIR}/local/
BSPFILEDONE="${INSTALLDIR}/.extracted_bsp"
ROOTFSFILEDONE="${INSTALLDIR}/.extracted_rootfs"
LOGFILE=${SCRIPT_DIR}/install.log
# Clear the logfile
echo "" > ${LOGFILE}

# Logging command.Adds timestamp, Appends to logfile and hides output.
shopt -s expand_aliases
alias installlog="tee -a ${LOGFILE} >/dev/null"
echo "HI!" | installlog

# Load the external utility scripts
source ${SCRIPT_DIR}/utils/textutils.sh
source ${SCRIPT_DIR}/utils/spinner.sh
source ${SCRIPT_DIR}/utils/cmdutils.sh

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

prompt "Download and install a working Linux4Tegra environment to ${BOLD}${INSTALLDIR}?${END}\nThis will require ~30GB of installation space. ${BOLD}[Y/n]${END} "

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

### DOWNLOAD ARCHIVES
BSPARCHIVE="jetson_linux_r32.6.1_aarch64.tbz2"
KERNSRCARCHIVE="public_sources.tbz2"
SAMPLEFSARCHIVE="tegra_linux_sample-root-filesystem_r32.6.1_aarch64.tbz2"
ARCHIVEDOWNLOAD=1


# If all three files exist, then we probably have them already. Ask if we want to download again
if test -f "$BSPARCHIVE" && test -f "$KERNSRCARCHIVE" && test -f "$SAMPLEFSARCHIVE"; then
    prompt "All three archive files exist on disk, do you want to redownload them before continuing? ${BOLD}[Y/n]${END} "
    case "$REPLY" in
        "")
            ;;
        [yY][eE][sS]|[yY]) 
            ;;
        *)
            echo "Skipping archive download..."
            ARCHIVEDOWNLOAD=0
            ;;
    esac
fi

if [ $ARCHIVEDOWNLOAD -eq 1 ]; then
    start_spinner "Downloading source archives..."
    nice_wget "https://developer.nvidia.com/embedded/l4t/r32_release_v6.1/t186/jetson_linux_r32.6.1_aarch64.tbz2" "${BSPARCHIVE}"
    nice_wget "https://developer.download.nvidia.com/embedded/L4T/r32_Release_v6.1/sources/T186/public_sources.tbz2" "${KERNSRCARCHIVE}"
    nice_wget "https://developer.nvidia.com/embedded/l4t/r32_release_v6.1/t186/tegra_linux_sample-root-filesystem_r32.6.1_aarch64.tbz2" "${SAMPLEFSARCHIVE}"
    stop_spinner $?
fi


### EXTRACT THESE ARCHIVES
start_spinner "Extracting jetson_linux_r32.6.1_aarch64.tbz2 in $(pwd)..."

# Check if we have already extracted this folder
if test -f "$BSPFILEDONE"; then
    echo "jetson_linux_r32.6.1_aarch64.tbz2 already extracted."
else
    # Extract the BSP, which makes the folder Linux_for_Tegra
    tar xf jetson_linux_r32.6.1_aarch64.tbz2
    # Touch the extract file
    touch $BSPFILEDONE
fi

stop_spinner $?


### EXTRACT THE ROOTFS
# Go to where we need to put the sample root filesystem
cd Linux_for_Tegra/rootfs/
start_spinner "Extracting tegra_linux_sample-root-filesystem_r32.6.1_aarch64.tbz2 in $(pwd)..."
# Extract the other archive into this location
if test -f "$ROOTFSFILEDONE"; then
    echo "tegra_linux_sample-root-filesystem_r32.6.1_aarch64.tbz2 already extracted."
else
    # Extract the BSP, which makes the folder Linux_for_Tegra
    sudo tar xpf ../../tegra_linux_sample-root-filesystem_r32.6.1_aarch64.tbz2
    # Touch the extract file
    touch $ROOTFSFILEDONE
fi
# Move up into the Linux_for_Tegra folder
cd ..
stop_spinner $?


### APPLY THE KERNEL BINARIES AND MODULES
start_spinner "Running ./apply_binaries.sh..."
# Run this script, which will basically install
# a bunch of applications into the rootfs
echo "Output being redirected to ${LOGFILE}"
sudo ./apply_binaries.sh | installlog
stop_spinner $?


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

### EXTRACT THE KERNEL SOURCES TO THE CORRECT DIR
cd $INSTALLDIR
start_spinner "Extracting public_sources.tbz2 in $(pwd)..."
tar -xjf public_sources.tbz2
stop_spinner $?

# Make the kernel source directory
mkdir -p $INSTALLDIR/Linux_for_Tegra/source/public
# Extract the kernel sources into it
cd $INSTALLDIR/Linux_for_Tegra/source/public
start_spinner "Extracting kernel_src.tbz2 in $(pwd)..."
tar -xjf $INSTALLDIR/Linux_for_Tegra/source/public/kernel_src.tbz2
stop_spinner $?

### INSTALL THE COMPILER TOOLCHAIN
start_spinner "Installing L4T compiler toolchain..."
echo "Output being redirected to ${LOGFILE}"
echo "Running sudo apt install build-essential bc"
sudo apt install build-essential bc | installlog
mkdir $INSTALLDIR/l4t-gcc
cd $INSTALLDIR/l4t-gcc
wget -q --show-progress -N http://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz -O gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
echo "Extracting..."
tar xf gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz | installlog
stop_spinner $?

### KERNEL SETUP AND PATCH
start_spinner "Patching kernel source in $(pwd)..."
cd $INSTALLDIR/Linux_for_Tegra/source/public/kernel/kernel-4.9

export CROSS_COMPILE=$INSTALLDIR/l4t-gcc/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
export LOCALVERSION=-tegra
export TEGRA_KERNEL_OUT=${INSTALLDIR}/Linux_for_Tegra/kernel-build

mkdir -p $TEGRA_KERNEL_OUT

echo "Applying patch to fix failure to build."
echo "See: https://forums.developer.nvidia.com/t/failed-to-make-l4t-kernel-dts/116399/7"

FILETOPATCH=${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9/scripts/Kbuild.include
PATCHFILE=${SCRIPT_DIR}/patches/Kbuild.include.patch
cat ${PATCHFILE} | patch -b -u ${FILETOPATCH}
stop_spinner $?


prompt "Would you like build the kernel now? This may take a while. ${BOLD}[Y/n]${END} "

case "$REPLY" in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "Quit. Kernel build toolchain installed."
        exit 1
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
