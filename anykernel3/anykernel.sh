# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

# Customized for NetHunter

## AnyKernel setup
# begin properties
properties() { '
kernel.string=NetHunter kernel
do.devicecheck=1
do.modules=1
do.cleanup=0
do.cleanuponabort=0
device.name1=oneplus6
device.name2=op6
device.name3=oneplus6t
device.name4=op6t
device.name5=enchilada
device.name6=fajita
device.name7=OnePlus6
device.name8=OnePlus6T
device.name9=
device.name10=
supported.versions=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## NetHunter additions

SYSTEM="/system";
SYSTEM_ROOT="/system_root";

setperm() {
	find "$3" -type d -exec chmod "$1" {} \;
	find "$3" -type f -exec chmod "$2" {} \;
}

install() {
	setperm "$2" "$3" "$home$1";
	if [ "$4" ]; then
		cp -r "$home$1" "$(dirname "$4")/";
		return;
	fi;
	cp -r "$home$1" "$(dirname "$1")/";
}

[ -d $home/system/etc/firmware ] && {
	install "/system/etc/firmware" 0755 0644 "$SYSTEM/etc/firmware";
}

[ -d $home/system/etc/init.d ] && {
	install "/system/etc/init.d" 0755 0755 "$SYSTEM/etc/init.d";
}

[ -d $home/system/lib ] && {
	install "/system/lib" 0755 0644 "$SYSTEM/lib";
}

[ -d $home/system/lib64 ] && {
	install "/system/lib64" 0755 0644 "$SYSTEM/lib64";
}

[ -d $home/system/bin ] && {
	install "/system/bin" 0755 0755 "$SYSTEM/bin";
}

[ -d $home/system/xbin ] && {
	install "/system/xbin" 0755 0755 "$SYSTEM/xbin";
}

[ -d $home/data/local ] && {
	install "/data/local" 0755 0644;
}

[ -d $home/ramdisk-patch ] && {
	setperm "0755" "0750" "$home/ramdisk-patch";
        chown root:shell $home/ramdisk-patch/*;
	cp -rp $home/ramdisk-patch/* "$SYSTEM_ROOT/";
}

if [ ! "$(grep /init.nethunter.rc $SYSTEM_ROOT/init.rc)" ]; then
  insert_after_last "$SYSTEM_ROOT/init.rc" "import .*\.rc" "import /init.nethunter.rc";
fi;

if [ ! "$(grep /dev/hidg* $SYSTEM_ROOT/ueventd.rc)" ]; then
  insert_after_last "$SYSTEM_ROOT/ueventd.rc" "/dev/kgsl.*root.*root" "# HID driver\n/dev/hidg* 0666 root root";
fi;

ui_print "Applying additional anykernel installation patches";
for p in $(find ak_patches/ -type f); do
  ui_print "Applying $p";
  . $p;
done

## End NetHunter additions

## Trim partitions
fstrim -v /cache;
fstrim -v /data;

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*;
chown -R root:root $ramdisk/*;

## AnyKernel install
dump_boot;

# begin ramdisk changes

if [ -d $ramdisk/.backup ]; then
  patch_cmdline "skip_override" "skip_override";
else
  patch_cmdline "skip_override" "";
fi;

# end ramdisk changes

write_boot;
## end install

