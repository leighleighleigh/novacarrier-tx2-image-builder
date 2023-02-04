# These utility functions are from
# https://github.com/IntelRealSense/librealsense

function try_unload_module {
	unload_module_name=$1
	op_failed=0

	modprobe -r ${unload_module_name} || op_failed=$?

	if [ $op_failed -ne 0 ];
	then
		echo -e "\e[31mFailed to unload module $unload_module_name. error type $op_failed . Operation is aborted\e[0m" >&2
		exit 1
	fi
}

function try_load_module {
	load_module_name=$1
	op_failed=0

	if [ $(lsmod | grep ^${load_module_name} | wc -l) -eq 0 ]; then
		modprobe ${load_module_name} || op_failed=$?
	else
		printf "\e[32mn/a\e[0m"
	fi
	
	if [ $op_failed -ne 0 ];
	then
		echo -e "\e[31mFailed to reload module $load_module_name. error type $op_failed . Operation is aborted\e[0m"  >&2
		exit 1
	fi
}

function try_module_insert {
	module_name=$1
	src_ko=$2
	tgt_ko=$3
	backup_available=1
	dependent_modules=""

	printf "\e[32mReplacing \e[93m\e[1m%s \e[32m -\n\e[0m" ${module_name}

	#Check if the module is loaded, and if does - are there dependent kernel modules.
	#Unload those first, then unload the requsted module and proceed with replacement
	#  lsmod | grep ^videodev
	#videodev              176128  4 uvcvideo,v4l2_common,videobuf2_core,videobuf2_v4l2
	# In the above scenario videodev cannot be unloaded untill all the modules listed on the right are unloaded
	# Note that in case of multiple dependencies we'll remove only modules one by one starting with the first on the list
	# And that the modules stack unwinding will start from the last (i.e leaf) dependency,
	# for instance : videobuf2_core,videobuf2_v4l2,uvcvideo will start with unloading uvcvideo as it should automatically unwind dependent modules
	if [ $(lsmod | grep ^${module_name} | wc -l) -ne 0 ];
	then
		dependencies=$(lsmod | grep ^${module_name} | awk '{printf $4}')
		dependent_module=$(lsmod | grep ^${module_name} | awk '{printf $4}' | awk -F, '{printf $NF}')
		if [ ! -z "$dependencies" ];
		then
			printf "\e[32m\tModule \e[93m\e[1m%s \e[32m\e[21m is used by \e[34m$dependencies\n\e[0m" ${module_name}
		fi
		while [ ! -z "$dependent_module" ]
		do
			printf "\e[32m\tUnloading dependency \e[34m$dependent_module\e[0m\n\t"
			dependent_modules+="$dependent_module "
			try_unload_module $dependent_module
			dependent_module=$(lsmod | grep ^${module_name} | awk '{printf $4}' | awk -F, '{printf $NF}')
		done

		# Unload existing modules if resident
		printf "\e[32mModule is resident, unloading ... \e[0m"
		try_unload_module ${module_name}
		printf "\e[32m succeeded. \e[0m\n"
	fi

	# backup the existing module (if available) for recovery
	if [ -f ${tgt_ko} ];
	then
		cp ${tgt_ko} ${tgt_ko}.bckup
	else
		backup_available=0
	fi

	# copy the patched module to target location
	cp ${src_ko} ${tgt_ko}

	# try to load the new module
	modprobe_failed=0
	printf "\e[32m\tApplying the patched module ... \e[0m"
	modprobe ${module_name} || modprobe_failed=$?

	# Check and revert the backup module if 'modprobe' operation crashed
	if [ $modprobe_failed -ne 0 ];
	then
		echo -e "\e[31mFailed to insert the patched module. Operation is aborted, the original module is restored\e[0m"
		echo -e "\e[31mVerify that the current kernel version is aligned to the patched module version\e[0m"
		if [ ${backup_available} -ne 0 ];
		then
			cp ${tgt_ko}.bckup ${tgt_ko}
			modprobe ${module_name}
			printf "\e[34mThe original \e[33m %s \e[34m module was reloaded\n\e[0m" ${module_name}
		fi
		exit 1
	else
		# Everything went OK, delete backup
		printf "\e[32m succeeded\e[0m"
		rm ${tgt_ko}.bckup
	fi

	# Reload all dependent modules recursively
	if [ ! -z "$dependent_modules" ];
	then
		#Retrieve the list of dependent modules that were unloaded
		modules_list=(${dependent_modules})
		for (( idx=${#modules_list[@]}-1 ; idx>=0 ; idx-- ));
		do
			printf "\e[32m\tReloading dependent kernel module \e[34m${modules_list[idx]} \e[32m... \e[0m"
			try_load_module ${modules_list[idx]}
			printf "\e[32m succeeded. \e[0m\n"
		done
	fi
	printf "\n"
}