# Sets up the install.env file
function setup_envfile()
{
    echo "#!/bin/bash" > ${ENVFILE}
    echo "# These are our global variables used to make the installation." >> ${ENVFILE}
    echo "# They are stored here for other scripts to use" >> ${ENVFILE}
}

# Downloads the required source archives from NVIDIA
function get_archives()
{
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
}

# Extracts the downloaded archives to make the Linux_for_Tegra directory
function extract_archives()
{
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
}

# Apply the binaries to the rootfs
function apply_binaries()
{
    ### APPLY THE KERNEL BINARIES AND MODULES
    start_spinner "Running ./apply_binaries.sh..."
    # Run this script, which will basically install
    # a bunch of applications into the rootfs
    echo "Output being redirected to ${LOGFILE}"
    sudo ./apply_binaries.sh | installlog
    stop_spinner $?
}

# Extract the kernel sources
function setup_kernel_sources()
{
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
    ### Write these to our env file
    echo "export CROSS_COMPILE=${CROSS_COMPILE}" >> ${ENVFILE}
    echo "export LOCALVERSION=${LOCALVERSION}" >> ${ENVFILE}
    echo "export TEGRA_KERNEL_OUT=${TEGRA_KERNEL_OUT}" >> ${ENVFILE}
    

    mkdir -p $TEGRA_KERNEL_OUT

    echo "Applying patch to fix failure to build."
    echo "See: https://forums.developer.nvidia.com/t/failed-to-make-l4t-kernel-dts/116399/7"

    FILETOPATCH=${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9/scripts/Kbuild.include
    PATCHFILE=${SCRIPT_DIR}/patches/Kbuild.include.patch
    patch -b -u ${FILETOPATCH} -i ${PATCHFILE} | installlog
    stop_spinner $?

    ### Write the relevant environment variables to file,
    # so we can source them later
}