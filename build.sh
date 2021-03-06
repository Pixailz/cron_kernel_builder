#!/bin/bash
# Bash Color
green='\e[32m'
red='\e[31m'
yellow='\e[33m'
blue='\e[34m'
lgreen='\e[92m'
lyellow='\e[93m'
lblue='\e[94m'
lmagenta='\e[95m'
lcyan='\e[96m'
blink_red='\033[05;31m'
restore='\033[0m'
reset='\e[0m'

# NetHunter Stage 1 Kernel Build Script
#
# This script if heavily based on work by holyangle
# https://gitlab.com/HolyAngel/op7
##############################################

##############################################
# Functions
## Pause
function pause() {
	local message="$@"
	[ -z $message ] && message="Press [Enter] to continue.."
	read -p "$message" readEnterkey
}

function info() {
		printf "${lcyan}[   INFO   ]${reset} $*${reset}\n"
}

function success() {
		printf "${lgreen}[ SUCCESS  ]${reset} $*${reset}\n"
}

function warning() {
		printf "${lyellow}[ WARNING  ]${reset} $*${reset}\n"
}

function error() {
		printf "${lmagenta}[  ERROR   ]${reset} $*${reset}\n"
}

function question() {
		printf "${yellow}[ QUESTION ]${reset} "
}

##############################################
# Compile Kernel
## Clean "out" folders
function make_oclean() {
	printf "\n"
	info "Cleaning up kernel-out & modules-out directories"
	## Let's make sure we dont't delete the kernel source if we compile in the source tree
	if [ "$KDIR" == "$KERNEL_OUT" ]; then
		# Clean the source tree as well if we use it to build the kernel, i.e. we have no OUT directory
		make -C $KDIR clean && make -C $KDIR mrproper
		rm -f $KDIR/source
	else
		rm -rf "$KERNEL_OUT"
	fi
	rm -rf "$MODULES_OUT"
	success "Out directories removed!"
}

## Clean source tree
function make_sclean() {
	local confdir=${KDIR}/arch/$ARCH/configs
	printf "\n"
	info "Cleaning source directory"
	if [ -f ${confdir}/$CONFIG.old ]; then
			rm -f ${confdir}/$CONFIG.old
	fi
	if [ -f ${confdir}/$CONFIG.new ]; then
			rm -f ${confdir}/$CONFIG.new
	fi
	success "Source directory cleaned"
}

## Create kernel compilation working directories
function setup_dirs() {
	info "Creating new out directory"
	mkdir -p "$KERNEL_OUT"
	success "Created new out directory"
	info "Creating new modules_out directory"
	mkdir -p "$MODULES_OUT"
	success "Created new modules_out directory"
}

## Select defconfig file
function select_defconfig() {
	local IFS opt options f i
	local confdir=${KDIR}/arch/$ARCH/configs
	info "Please select the configuration you would like to use as basis"
	printf "\n"
	cd $confdir
	while IFS= read -r -d $'\0' f; do
		options[i++]="$f"
	done < <(find * -type f -print0 )

	select opt in "${options[@]}" "Cancel"; do
		case $opt in
		"Cancel")
			cd -
			return 1
			;;
		*)
			cd -
			break
			;;
		esac
	done
	info "Using ${opt} as new ${CONFIG}"
	cp ${confdir}/${opt} ${confdir}/${CONFIG}
	return 0
}

## Check if $CONFIG exists and create it if not
function get_defconfig() {
	local defconfig
	local confdir=${KDIR}/arch/$ARCH/configs
	printf "\n"
	if [ ! -f ${confdir}/${CONFIG} ]; then
		warning "${CONFIG} not found, creating."
		select_defconfig
		return $?
	fi
	return 0
}

## Edit .config in working directory
function edit_config() {
	local cc
	printf "\n"
	# CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"
	fi
	get_defconfig || return 1
	info "Create config"
	make -C $KDIR O="$KERNEL_OUT" $cc $CONFIG
	cfg_done=true
}

## Enable ccache to speed up compilation
function enable_ccache() {
	if [ "$CCACHE" = true ]; then
		if [ "$CC" == "clang" ]; then
			CC="ccache clang"
			else
			if [ ! -z "${CC}" ] && [[ ${CC} != ccache* ]]; then
				CC="ccache $CC"
			fi
			if [ ! -z "${CROSS_COMPILE}" ] && [[ ${CROSS_COMPILE} != ccache* ]]; then
				export CROSS_COMPILE="ccache ${CROSS_COMPILE}"
			fi
			if [ ! -z "${CROSS_COMPILE_ARM32}" ] && [[ ${CROSS_COMPILE_ARM32} != ccache* ]]; then
				export CROSS_COMPILE_ARM32="ccache ${CROSS_COMPILE_ARM32}"
			fi
		fi
		info "~~~~~~~~~~~~~~~~~~"
		info " ccache enabled"
		info "~~~~~~~~~~~~~~~~~~"
	fi
	return 0
}

## copy version file across
function copy_version() {
	if [ ! -z ${SRC_VERSION} ] && [ ! -z ${TARGET_VERSION} ] && [ -f ${SRC_VERSION} ]; then
		cp -f ${SRC_VERSION} ${TARGET_VERSION}
	fi
	return 0
}

## Compile the kernel
function make_kernel() {
	local cc
	local confdir=${KDIR}/arch/$ARCH/configs
	printf "\n"
	# CC=clang cannot be exported. Let's compile with clang if "CC" is set to "clang" in the config
	if [ "$CC" == "clang" ]; then
		cc="CC=clang"
	fi
	enable_ccache
	echo ${CC}
	echo ${CROSS_COMPILE}
	echo ${CROSS_COMPILE_ARM32}
	info "~~~~~~~~~~~~~~~~~~"
	info " Building kernel"
	info "~~~~~~~~~~~~~~~~~~"
	copy_version
	grep "CONFIG_MODULES=y" ${KERNEL_OUT}/.config >/dev/null && MODULES=true
	## Some kernel sources do not compile into a separate $OUT directory so we set $OUT = $ KDIR
	## This works with clean and config targets but not for a build, we'll catch this here
	if [ "$KDIR" == "$KERNEL_OUT" ]; then
		if [ "$CC" == "ccache clang" ]; then
			time make -C $KDIR CC="ccache clang"  -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
					time make -C $KDIR CC="ccache clang" -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		else
			time make -C $KDIR $cc -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
					time make -C $KDIR $cc -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		fi
	else
		if [ "$CC" == "ccache clang" ]; then
			time make -C $KDIR O="$KERNEL_OUT" CC="ccache clang" -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
				time make -C $KDIR O="$KERNEL_OUT" CC="ccache clang" -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		else
			time make -C $KDIR O="$KERNEL_OUT" $cc -j "$THREADS" ${MAKE_ARGS}
			if [ "$MODULES" = true ]; then
				time make -C $KDIR O="$KERNEL_OUT" $cc -j "$THREADS" INSTALL_MOD_PATH=$MODULES_OUT modules_install
			fi
		fi
	fi
	rm -f ${MODULES_OUT}/lib/modules/*/source
	rm -f ${MODULES_OUT}/lib/modules/*/build
	success "Kernel build completed"
}

function compile_kernel() {
	make_oclean
	make_sclean
	setup_dirs
	edit_config && make_kernel
}
##############################################

##############################################
# Create Anykernel Zip
## Clean anykernel directory
function make_aclean() {
	printf "\n"
	info "Cleaning up anykernel zip directory"
	rm -rf $ANYKERNEL_DIR/Image* $ANYKERNEL_DIR/dtb $CHANGELOG ${ANYKERNEL_DIR}/modules ${ANYKERNEL_DIR}/*.zip
	success "Anykernel directory cleaned"
}

## Generate Changelog
function make_clog() {
	printf "\n"
	cd $BUILD_DIR
	info "Generating Changelog"
	rm -rf $CHANGELOG
	touch $CHANGELOG
	for i in $(seq 180);
	do
		local After_Date=`date --date="$i days ago" +%F`
		local kcl=$(expr $i - 1)
		local Until_Date=`date --date="$kcl days ago" +%F`
		printf "====================" >> $CHANGELOG;
		printf "     $Until_Date    " >> $CHANGELOG;
		printf "====================" >> $CHANGELOG;
		git log --after=$After_Date --until=$Until_Date --pretty=tformat:"%h  %s  [%an]" --abbrev-commit --abbrev=7 >> $CHANGELOG
		printf "" >> $CHANGELOG;
	done
	sed -i 's/project/ */g' $CHANGELOG
	sed -i 's/[/]$//' $CHANGELOG
	info "Done"
	cd $ANYKERNEL_DIR
}

## Generate the anykernel zip
function make_anykernel_zip() {
	printf "\n"
	mkdir -p ${UPLOAD_DIR}
	info "Copying kernel to anykernel zip directory"
	if [[ ! -f "$KERNEL_IMAGE" ]]; then
		warning "File missing. try relaunching scripts"
	else
		cp "$KERNEL_IMAGE" "$ANYKERNEL_DIR"
	fi
	if [ "$DO_DTBO" = true ]; then
		info "Copying dtbo to zip directory"
		cp "$DTBO_IMAGE" "$ANYKERNEL_DIR"
	fi
	if [ "$DO_DTB" = true ]; then
		info "Generating dtb in zip directory"
		make_dtb ${ANYKERNEL_DIR}
	fi
	if [ -d ${MODULES_OUT}/lib ]; then
		info "Copying modules to zip directory"
		mkdir -p ${ANYKERNEL_DIR}/${MODULE_DIRTREE}
		cp -r ${MODULES_IN} ${ANYKERNEL_DIR}/${MODULE_DIRTREE}
	fi
	success "Done"
	make_clog
	printf "\n"
	info "Creating anykernel zip file"
	cd "$ANYKERNEL_DIR"
	sed -i "/Version/c\   Version=\"$CURRENT_BRANCH_SHORT7\"" banner
	zip -r "$ANY_ARCHIVE" *
	info "Moving any_kimo_${CURRENT_BRANCH_SHORT7}.zip"
	cp ${ANY_ARCHIVE} ${OUTPUT_ZIP_FOLDER}
	printf "\n"
	cd $BUILD_DIR
}

function create_anykernel_zip() {
	make_aclean
	make_anykernel_zip
}
##############################################

##############################################
# SetupEnv and update git as needed
function set_up_env() {
	BUILD_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	source ${BUILD_DIR}/config
}

function git_update() {
	git fetch
	set_up_env
	if [[ "${CURRENT_BRANCH_ID}" == "${LATEST_BRANCH_ID}" ]]; then
		info "Already up-to-date"
	else
		warning "Not up-to-date"
		if [[ "${CURRENT_BRANCH_NAME}" != "${LATEST_BRANCH_NAME}" ]]; then
			info "The Latest commit is comming from an another branches"
			info "switching to it"
			git checkout "${LATEST_BRANCH_NAME}" -f
			git pull
		else
			info "Pulling repo"
			git reset --hard HEAD && git pull
		fi
	fi
}
##############################################

##############################################
# Main

git_update

compile_kernel

create_anykernel_zip
#
##############################################
