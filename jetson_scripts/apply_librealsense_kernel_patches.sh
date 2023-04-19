#!/usr/bin/env bash

# This applies some pre-compiled patches to the uvcvideo and videobuf modules
# So that librealsense is happy, and can use the V4L-native backend rather than the UVC/RS_USB backend
# Source the patch utils from the same directory as this script
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/patch_utils.sh

DRY_RUN=0

# If --dry-run is passed as an argument, set DRY_RUN to 1
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=1
fi

# Nicer wget output
function nice_wget {
    sudo wget -q --show-progress -np $@
}

# If we're running in dry run mode, commands like 'cp' and 'modprobe' are not executed
# but their intended behaviour is printed to the console.
# When not running in dry mode, they are executed with 'sudo'
function cp() {
    if [ "$DRY_RUN" == "1" ]; then
        echo -e "\ncp $@"
    else
        echo -e "\ncp $@"
        sudo cp $@
    fi
}
function rm() {
    if [ "$DRY_RUN" == "1" ]; then
        echo -e "\nrm $@"
    else
        echo -e "\nrm $@"
        sudo rm $@
    fi
}
function modprobe() {
    if [ "$DRY_RUN" == "1" ]; then
        echo -e "\nmodprobe $@"
    else
        echo -e "\nmodprobe $@"
        sudo modprobe $@
    fi
}
function depmod() {
    if [ "$DRY_RUN" == "1" ]; then
        echo -e "\ndepmod"
    else
        echo -e "\ndepmod"
        sudo depmod
    fi
}

# First we check that the kernel version is 4.9.253-tegra
# If it is, we apply the patches
# If it isn't, we do nothing
TARGET_KERNEL_VERSION="4.9.253-tegra"
CURRENT_KERNEL_VERSION=$(uname -r)

if [ "$CURRENT_KERNEL_VERSION" == "$TARGET_KERNEL_VERSION" ]; then
    echo "Kernel version is $CURRENT_KERNEL_VERSION, applying patches..."
else
    echo "Kernel version is $CURRENT_KERNEL_VERSION, not applying patches"
    # If dry run, continue
    if [ "$DRY_RUN" == "1" ]; then
        echo "Running in dry run mode, continuing..."
    else
        exit 1
    fi
fi

PATCHED_UVCVIDEO_URI="https://github.com/leighleighleigh/librealsense/releases/download/v0.0.2/uvcvideo.ko"
PATCHED_VIDEOBUFCORE_URI="https://github.com/leighleighleigh/librealsense/releases/download/v0.0.2/videobuf-core.ko"
PATCHED_VIDEOBUFVMALLOC_URI="https://github.com/leighleighleigh/librealsense/releases/download/v0.0.2/videobuf-vmalloc.ko"

# Download these files to /tmp
nice_wget -O /tmp/uvcvideo.ko $PATCHED_UVCVIDEO_URI
nice_wget -O /tmp/videobuf-core.ko $PATCHED_VIDEOBUFCORE_URI
nice_wget -O /tmp/videobuf-vmalloc.ko $PATCHED_VIDEOBUFVMALLOC_URI

# Copy them to the correct locations
cp /tmp/uvcvideo.ko /lib/modules/${TARGET_KERNEL_VERSION}/kernel/drivers/media/usb/uvc/
cp /tmp/videobuf-core.ko /lib/modules/${TARGET_KERNEL_VERSION}/kernel/drivers/media/v4l2-core/
cp /tmp/videobuf-vmalloc.ko /lib/modules/${TARGET_KERNEL_VERSION}/kernel/drivers/media/v4l2-core/

# Run depmod
depmod

# Try to insert the new modules
# Since videobuf2 is a dependency of uvcvideo, it automatically gets inserted
try_module_insert uvcvideo /tmp/uvcvideo.ko /lib/modules/${TARGET_KERNEL_VERSION}/kernel/drivers/media/usb/uvc/uvcvideo.ko

# Function to replace the kernel image
function replace_kernel_image() {
    # Download the patched kernel image
    PATCHED_KERNEL_IMAGE_URI="https://github.com/leighleighleigh/librealsense/releases/download/v0.0.2/Image"
    nice_wget -O /tmp/Image $PATCHED_KERNEL_IMAGE_URI

    # Copy it to the correct location
    cp /tmp/Image /boot/Image
}

# Function to update the DTB file
function update_dtb() {
    # Download the patched DTB file
    PATCHED_DTB_URI="https://github.com/leighleighleigh/librealsense/releases/download/v0.0.2/kernel_tegra186-quill-p3310-1000-c03-00-base.dtb"
    nice_wget -O /tmp/kernel_tegra186-quill-p3310-1000-c03-00-base.dtb $PATCHED_DTB_URI

    # Copy it to the correct location
    cp /tmp/kernel_tegra186-quill-p3310-1000-c03-00-base.dtb /boot/dtb/kernel_tegra186-quill-p3310-1000-c03-00-base.dtb
    # Also copy to /boot
    cp /tmp/kernel_tegra186-quill-p3310-1000-c03-00-base.dtb /boot/kernel_tegra186-quill-p3310-1000-c03-00-base.dtb
}

# Ask if we want to replace the kernel image with the patched one (default NO)
read -p "[ADVANCED] Do you want to replace the kernel image with the patched one? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    replace_kernel_image
fi

# Ask if we want to update the DTB file (default No)
read -p "[ADVANCED] Do you want to update the DTB file? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    update_dtb
fi

# Print a message to say the user should reboot and try cameras again
echo "Please reboot your device, and try the realsense cameras again"

