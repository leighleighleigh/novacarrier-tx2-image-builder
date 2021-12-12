# Apply kernel source changes
function apply_nova_dts()
{
    # Copies the files in dts to their proper location
    NOVA_DTS="${SCRIPT_DIR}/dts/"
    KERNSRCDIR="${INSTALLDIR}/Linux_for_Tegra/"
    
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
        echo "Copying $f to $targetDir"
        cp $f $targetDir
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
    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j4 dtbs"
    cd "${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9"
    # Build, there are different targets here
    # make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 Image
    # make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules_prepare
    # make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j12 modules
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j4 dtbs
    stop_spinner $?
}

function install_dtbs()
{
    start_spinner "Installing newly built DTS/DTB files..."
    
    if [ ! -d "${INSTALLDIR}/Linux_for_Tegra/kernel/dtb-old" ] 
    then
        echo "Copying ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb to ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb-old"
        cp -r ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb-old
    fi

    echo "Replacing OLD ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb with NEW ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts"
    rm -R ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb
    echo "Copying ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts to ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb"
    cp -r ${TEGRA_KERNEL_OUT}/arch/arm64/boot/dts ${INSTALLDIR}/Linux_for_Tegra/kernel/dtb
    stop_spinner $?
}