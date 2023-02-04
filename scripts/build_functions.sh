# Apply kernel source changes
function apply_nova_dts()
{
    # Copies the files in dts to their proper location
    NOVA_DTS="${SCRIPT_DIR}/dts/"
    TARGETPREFIX="${INSTALLDIR}/Linux_for_Tegra/"
    
    # For each non *txt in the NOVA_DTS folder, we read the filepath from it's accomanying .txt file, and copy it there.
    # Each <filename>.txt must be a single line, with it's target path.
    # This path MUST BE relative to the Linux_for_Tegra folder

    for f in ${NOVA_DTS}*; do
        # Skip if the file ends with .txt
        [[ $f == *.txt ]] && continue
        # Now $f is our filename. We want to find it's .txt friend again, so we can find the copy path
        txtFriend="${f}.txt"
        # Read the first line of the txt file
        targetDir=$(head -n 1 $txtFriend)
        # Copy the file
        echo "Copying $f to ${TARGETPREFIX}${targetDir}"
        cp $f ${TARGETPREFIX}${targetDir}
    done
}

# Builds the DTBS in the kernel folder
function setup_make()
{
    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig"
    cd "${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig
    stop_spinner $?
}

function compile_dtbs()
{  
    # Enter the kernel source dir
    #cd "${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9"
    cd ${TEGRA_KERNEL_SRC}

    # TEGRA_KERNEL_OUT = Linux_for_Tegra/kernel-build
    # TEGRA_KERN_MODULE_OUT = Linux_for_Tegra/kernel-modules
    # TEGRA_KERNEL_SRC = Linux_for_Tegra/source/public/kernel/kernel-4.9

    # Build, there are different targets here. Only dtbs are needed for the dtb-only patches.
    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 Image"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 Image
    stop_spinner $?

    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_prepare"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_prepare
    stop_spinner $?

    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules
    stop_spinner $?

    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j4 dtbs"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j4 dtbs
    stop_spinner $?
    
    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_install INSTALL_MOD_PATH=${TEGRA_KERN_MODULE_OUT}"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_install INSTALL_MOD_PATH=${TEGRA_KERN_MODULE_OUT}
    stop_spinner $?
}

# Convenience function used to backup a directory.
# Given a directory path, it will copy it recursively to a new directory with the same name, but with a timestamp appended.
function make_backup_dir()
{
    # $1 = Directory to backup
    # $2 = Optional, if set to "true", will not append a timestamp to the backup directory name
    # $3 = Optional, if set to "true", will not create the backup directory if it already exists

    # If the directory doesn't exist, we can't backup it
    if [ ! -d "$1" ]
    then
        echo "Directory $1 does not exist, cannot backup"
        return 1
    fi

    # If the directory already exists, and we don't want to overwrite it, we can't backup it
    if [ -d "$1-backup" ] && [ "$3" != "true" ]
    then
        echo "Directory $1-backup already exists, cannot backup"
        return 1
    fi

    # If the directory already exists, and we want to overwrite it, we can backup it
    if [ -d "$1-backup" ] && [ "$3" == "true" ]
    then
        echo "Directory $1-backup already exists, overwriting"
        rm -R "$1-backup"
    fi

    # If we don't want to append a timestamp, we can backup it
    if [ "$2" == "true" ]
    then
        echo "Backing up $1 to $1-backup"
        cp -r "$1" "$1-backup"
        return $?
    fi

    # If we want to append a timestamp, we can backup it
    echo "Backing up $1 to $1-backup-$(date +%Y%m%d-%H%M%S)"
    cp -r "$1" "$1-backup-$(date +%Y%m%d-%H%M%S)"
    return $?
}

function install_dtbs()
{
    start_spinner "Installing newly built DTS/DTB files..."

    DTB_DIR="${INSTALLDIR}/Linux_for_Tegra/kernel/dtb"
    # Make backup of old dtb directory
    make_backup_dir "${DTB_DIR}"

    echo "Replacing OLD ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb with NEW ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts"
    rm -R ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb
    echo "Copying ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts to ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb"
    cp -r ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb
    stop_spinner $?
  
    # Also install the other stuffs
    # See here: https://developer.ridgerun.com/wiki/index.php/Compiling_Jetson_TX2_source_code_L4T_32.1

    # Copy image to the kernel image install dir for flash.sh
    cp $TEGRA_KERNEL_OUT/arch/arm64/boot/Image ${INSTALLDIR}/Linux_for_Tegra/kernel/

    LIB_DIR=${INSTALLDIR}/Linux_for_Tegra/rootfs/lib
    # Make backup of old lib directory
    make_backup_dir "${LIB_DIR}"

    # Copy modules to the rootfs/lib
    cp -ar $TEGRA_KERN_MODULE_OUT/lib ${INSTALLDIR}/Linux_for_Tegra/rootfs/
}
