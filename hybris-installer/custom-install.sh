#!/sbin/sh
# An extensible custom Hybris Installer script.
# https://git.io/fjMH9

# Details about this version:
#   Release : %VERSION%
#   Size    : ~%IMAGE_SIZE%

# >>> TWRP init >>>

OUTFD="" # e.g. "/proc/self/fd/28"

# Temporary: Find TWRP screen output FD for logging to it from here
for FD in `ls /proc/$$/fd`; do
	readlink /proc/$$/fd/$FD 2>/dev/null | grep pipe >/dev/null
	if [ "$?" -eq "0" ]; then
		ps | grep " 3 $FD " | grep -v grep >/dev/null
		if [ "$?" -eq "0" ]; then
			OUTFD="/proc/self/fd/$FD"
			break
		fi
	fi
done

# Print some text ($1) on the screen
ui_print() {
	[ -z "$1" ] && echo -e "ui_print  \nui_print" > $OUTFD || echo -e "ui_print $@\nui_print" > $OUTFD
}

# Before quitting with an exit code ($1), show a message ($2)
abort() {
	ui_print "E$1: $2"
	exit $1
}

# <<< TWRP init <<<

# >>> Custom functions >>>

# Log some text ($1) for script debugging
log() {
	echo "custom-install: $@"
}

# <<< Custom functions <<<

# Constants
VERSION="%VERSION%" # e.g. "3.1.0.12 (Seitseminen)"
INIT_PERF="/vendor/etc/init/hw/init.target.performance.rc"
TARGET_LOS_VER="15.1"

# >>> Sanity checks >>>

# ext4 check for /cache & /data
mount | grep /cache | grep ext4 &> /dev/null || abort 1 "Cache is not formatted as ext4; check out 'Wipe > Advanced' from TWRP!"
mount | grep /data | grep ext4 &> /dev/null || abort 2 "Data is not formatted as ext4; check out 'Wipe > Advanced' from TWRP!"

# Treble
if [ ! -r /dev/block/bootdevice/by-name/vendor ]; then
	abort 3 "A vendor partition doesn't exist; you need to do an OTA from OxygenOS 5.1.5 to 5.1.6!"
fi

# Android
umount /vendor &> /dev/null
mount -o rw /vendor || abort 4 "Couldn't mount /vendor!"
umount /system &> /dev/null
mount /system || abort 5 "Couldn't mount /system!"
[[ "$(cat /system/build.prop | grep lineage.build.version= | cut -d'=' -f2)" = "$TARGET_LOS_VER" && -f $INIT_PERF ]] || abort 6 "Please factory reset & dirty flash LineageOS $TARGET_LOS_VER before this zip."
umount /system &> /dev/null
[ -f $INIT_PERF.bak ] && abort 7 "This zip is NOT an OTA and should not be treated like one. Please reflash everything to ensure a proper fresh install!"

# <<< Sanity checks <<<

# >>> Script >>>

# Calculate centering offset indent on left
offset=`echo -n $VERSION | wc -m` # Character length of the version string
offset=`expr 52 - 23 - $offset`   # Remove constant string chars from offset calculation
offset=`expr $start / 2`          # Get left offset char count instead of space on both sides

# Build the left side indentation offset string
for i in `seq 1 $offset`; do indent="${indent} "; done

# Splash
ui_print
ui_print "-===============- Hybris Installer -===============-"
ui_print
ui_print "                          .':oOl."
ui_print "                       ':c::;ol."
ui_print "                    .:do,   ,l."
ui_print "                  .;k0l.   .ll.             .."
ui_print "                 'ldkc   .,cdoc:'.    ..,;:::;"
ui_print "                ,o,;o'.;::;'.  'coxxolc:;'."
ui_print "               'o, 'ddc,.    .;::::,."
ui_print "               cl   ,x:  .;:c:,."
ui_print "               ;l.   .:ldoc,."
ui_print "               .:c.    .:ll,"
ui_print "                 'c;.    .;l:"
ui_print "                   :xc.    ,o'"
ui_print "                   'xxc.   ;o."
ui_print "                   :l'c: ,lo,"
ui_print "                  ,o'.ooclc'"
ui_print "                .:l,,x0o;."
ui_print "              .;llcldl,"
ui_print "           .,oOOoc:'"
ui_print "       .,:lddo:'."
ui_print "      oxxo;."
ui_print
ui_print "${indent}Installing Sailfish OS $VERSION"
ui_print "                   Please wait ..."

# Start
log "Patching TWRP's broken tar..."
(cp /tmp/tar /sbin/tar && chmod 777 /sbin/tar) || abort 8 "Couldn't patch tar!"

log "Extracting SFOS rootfs..."
ARCHIVE="/tmp/sfos-rootfs.tar.bz2"
ROOT="/data/.stowaways/sailfishos"
rm -rf $ROOT/
mkdir -p $ROOT/
tar --numeric-owner -xvjf $ARCHIVE -C $ROOT/ || abort 9 "Couldn't extract SFOS rootfs!"
rm $ARCHIVE

log "Fixing up init scripts..."
cp $INIT_PERF $INIT_PERF.bak
rm $ROOT/init.extraenv.armeabi-v7a.rc
(sed -e "/extraenv/s/^/#/g" -e "/ro.hardware/s/^/#/g" -e "s/\/cpus\ /\/cpuset.cpus /g" -e "s/\/cpus$/\/cpuset.cpus/g" -e "s/\/mems\ /\/cpuset.mems /g" -e "s/\/mems$/\/cpuset.mems/g" -i $ROOT/init.rc && sed -e "s/cpus 0/cpuset.cpus 0/g" -e "s/mems 0/cpuset.mems 0/g" -i $INIT_PERF) || log "Couldn't fix-up init scripts!"

log "Disabling forced encryption in vendor fstab..."
sed "s/fileencryption/encryptable/" -i /vendor/etc/fstab.qcom || log "Couldn't disable forced encryption!"

log "Backing up droid-boot image..."
dd if=/dev/block/bootdevice/by-name/boot of=$ROOT/boot/droid-boot.img

log "Switching to hybris-boot image..."
dd if=$ROOT/boot/hybris-boot.img of=/dev/block/bootdevice/by-name/boot || abort 10 "Couldn't write Hybris boot image!"

log "Cleaning up..."
umount /vendor &> /dev/null

# <<< Script <<<

# Succeeded.
ui_print "            All done, enjoy your new OS!"
ui_print
exit 0