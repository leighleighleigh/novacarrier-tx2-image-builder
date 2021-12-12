# Builds the DTBS in the kernel folder
function setup_make()
{
    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig"
    make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} tegra_defconfig
    stop_spinner $?
}

function compile_dtbs()
{  
    start_spinner "make ARCH=arm64 O=$TEGRA_KERNEL_OUT CROSS_COMPILE=${CROSS_COMPILE} -j4 dtbs"
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
    
    if [ ! -d "${INSTALLDIR}/Linux_for_Tegra/source/public/kernel/kernel-4.9" ] 
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