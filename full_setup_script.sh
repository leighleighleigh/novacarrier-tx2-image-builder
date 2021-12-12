#!/bin/bash

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

# Custom nova text
title "Jetson Carrier Kernel: Build Environment Setup Tool"

# Check for root
if [[ "$(whoami)" != root ]]; then
  printf "${ERROR}Please run this script as root!${END}\n"
  printf "${ERROR}This is neccesary to use QEMU${END}\n"
  exit 1
fi

# Get location of this script. This is different to the current working directory, which could be anywhere!
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Define the install dir
INSTALLDIR=${SCRIPT_DIR}/local/

BSPFILEDONE="${INSTALLDIR}/.extracted_bsp"
ROOTFSFILEDONE="${INSTALLDIR}/.extracted_rootfs"

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

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo -ne ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : command exit status
    # Add sleep so it will always show
    sleep 0.5
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

function nice_wget {
    # Numper of args is $#
    if [ $# -eq 2 ]
    then
        # URL is $1
        # Output file is $2
        wget -q --show-progress -np -N $1 -O $2
    else
        echo "nice_get invalid arguments, got: $*"
        exit 1
    fi
}

### DIRECTORY SETUP
start_spinner "mkdir ${INSTALLDIR} && cd ${INSTALLDIR}"
mkdir -p $INSTALLDIR && cd $INSTALLDIR
stop_spinner $?

# Start log
echo "START NOVACARRIER KERNEL DEV SETUP LOG" > ${INSTALLDIR}/.install_log

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
echo "Output being redirected to ${INSTALLDIR}/.install_log"
sudo ./apply_binaries.sh | tee -a ${INSTALLDIR}/.install_log
stop_spinner $?

# Prompt for the install thing
prompt "Would you like setup the kernel source files, and install the compilation toolchain? ${BOLD}[Y/n]${END} "
case "$REPLY" in
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
echo "Output being redirected to ${INSTALLDIR}/.install_log"
echo "Running sudo apt install build-essential bc"
sudo apt install build-essential bc | tee -a ${INSTALLDIR}/.install_log
mkdir $INSTALLDIR/l4t-gcc
cd $INSTALLDIR/l4t-gcc
wget -q --show-progress -N http://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz -O gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
echo "Extracting..."
tar xf gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz | tee -a ${INSTALLDIR}/.install_log
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

FILETOPATCH=$INSTALLDIR/Linux_for_Tegra/source/public/kernel/kernel-4.9/scripts/Kbuild.include
echo '--- Kbuild.include	2021-07-27 05:08:17.000000000 +1000
+++ Kbuild.include.fixed	2021-12-11 19:18:02.082926326 +1100
@@ -461,8 +461,8 @@
 # It'\''s a common trick to declare makefile variable that contains space
 # we'\''ll need it to convert the path string to list (string delimited by spaces)
 # and vice versa
-the-space :=
-the-space += 
+E =
+the-space = $E $E
 # TEGRA_ROOT_PATH is the relative path to the directory one level upper than $srctree
 _TEGRA_ROOT_PATH = $(subst ^$(realpath $(srctree)/..)/,,^$(realpath $(kbuild-dir)))
 # _TEGRA_REL_PATH is path like "../../../" that points to directory one level
' | patch -b -u $FILETOPATCH
stop_spinner $?


prompt "Would you like build the kernel now? This may take a while. ${BOLD}[Y/n]${END} "

case "$REPLY" in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "Quit. Kernel compilatino toolchain done"
        exit 1
        ;;
esac

# Setup
start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig"
make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig
stop_spinner $?

start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 dtbs"
echo "Output being redirected to ${INSTALLDIR}/.install_log"
# Build, there are different targets here
# make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 Image
# make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_prepare
# make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules
make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 dtbs | tee -a ${INSTALLDIR}/.install_log
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
