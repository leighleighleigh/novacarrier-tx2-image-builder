#!/usr/bin/bash

# The setting for the boot console is passed to the kernel from some dtsi file.
# These are stored in a variable named ${cbootargs}

# These arguments are passed from C-Boot to the Kernel via the arguments in 
# /boot/extlinux/extlinux.conf

# The relevant line looks like
#APPEND ${cbootargs} quiet root=/dev/mmcblk0p1 rw rootwait rootfstype=ext4 console=ttyS0,115200n8 console=tty0 OS=l4t fbcon=map:0 net.ifnames=0

# In order to keep all the important settings that were setup in ${cbootargs}, we will capture the entire command line args used at runtime and then
# override them in the extlinux.conf file manually.

# Print the current command line paramters
echo "Current commandline parameters:"
cat /proc/cmdline

echo "Current extlinux.conf contents used by C-Boot"
cat /boot/extlinux/extlinux.conf

echo "Resultant string which needs cleaning"
echo "SCRIPT NOT DONE YET LMAO"
