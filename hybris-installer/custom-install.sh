#!/sbin/sh
# An extensible custom Hybris Installer script.
# https://git.io/fjMH9

# Details about this version:
#   Release : v%VERSION%
#   Size    : ~%IMAGE_SIZE%

# >>> Get TWRP output pipe fd >>>

OUTFD=0

# we are probably running in embedded mode, see if we can find the right fd
# we know the fd is a pipe and that the parent updater may have been started as
# 'update-binary 3 fd zipfile'
for FD in `ls /proc/$$/fd`; do
	readlink /proc/$$/fd/$FD 2>/dev/null | grep pipe >/dev/null
	if [ "$?" -eq "0" ]; then
		ps | grep " 3 $FD " | grep -v grep >/dev/null
		if [ "$?" -eq "0" ]; then
			OUTFD=$FD
			break
		fi
	fi
done

# <<< Get TWRP output pipe fd <<<

# >>> Implement TWRP functions >>>

ui_print() {
	echo -en "ui_print $1\n" >> /proc/self/fd/$OUTFD
	echo -en "ui_print\n" >> /proc/self/fd/$OUTFD
}

# TODO: Implement show_progress function

# <<< Implement TWRP functions <<<

# >>> Custom functions >>>

# TODO Write to stderr if TWRP output in RED

# Write error message & exit.
# args: 1=errcode, 2=msg
abort() {
	ui_print "$2"
	exit $1
}

log() {
	echo "custom-install: $@"
}

# <<< Custom functions <<<

# >>> Sanity checks >>>

# ext4 check for /cache & /data
mount | grep /data | grep ext4 &> /dev/null || abort 1 "Data is not formatted as ext4!"
mount | grep /cache | grep ext4 &> /dev/null || abort 2 "Cache is not formatted as ext4!"

# Treble
if [ ! -r /dev/block/bootdevice/by-name/vendor ]; then
	abort 3 "Vendor partition doesn't exist; you need to do an OTA from OxygenOS 5.1.5 to 5.1.6!"
fi

# Android
umount /vendor &> /dev/null
mount -o rw /vendor || abort 4 "Couldn't mount /vendor!"
umount /system &> /dev/null
mount /system || abort 5 "Couldn't mount /system!"
[[ "$(cat /system/build.prop | grep lineage.build.version= | cut -d'=' -f2)" = "15.1" && -f /vendor/etc/init/hw/init.qcom.rc ]] || abort 6 "Please factory reset & dirty flash LineageOS 15.1 before this zip."
umount /system &> /dev/null

# <<< Sanity checks <<<

# >>> Script start >>>

# Calculate centering offset indent on left
VERSION="%VERSION%" # e.g. "3.0.3.10 (Hossa)"
target_len=`echo -n $VERSION | wc -m` # e.g. 16 for "3.0.3.10 (Hossa)"
start=`expr 52 - 24 - $target_len` # e.g. 12
start=`expr $start / 2` # e.g. 6
log "indent offset is $start for '$TARGET_PRETTY'"

indent=""
for i in `seq 1 $start`; do
	indent="${indent} "
done

# Splash
ui_print " "
ui_print "-===============- Hybris Installer -===============-"
ui_print " "
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
ui_print " "
ui_print "${indent}Installing Sailfish OS v$VERSION"
ui_print "                   Please wait ..."

# Script

log "Patching TWRP's broken tar..."
(cp /tmp/tar /sbin/tar && chmod 777 /sbin/tar) || abort 7 "Couldn't patch tar!"

log "Extracting SFOS rootfs..."
ARCHIVE="/tmp/sailfishos-rootfs.tar.bz2"
ROOT="/data/.stowaways/sailfishos"
rm -rf $ROOT/
mkdir -p $ROOT/
tar --numeric-owner -xvjf $ARCHIVE -C $ROOT/ || abort 8 "Couldn't extract SFOS rootfs!"
rm $ARCHIVE

log "Fixing up init scripts..."
(sed -e "/extraenv/s/^/#/g" -e "/ro.hardware/s/^/#/g" -e "s/\/cpus\ /\/cpuset.cpus /g" -e "s/\/cpus$/\/cpuset.cpus/g" -e "s/\/mems\ /\/cpuset.mems /g"  -e "s/\/mems$/\/cpuset.mems/g" -i $ROOT/init.rc && sed -e "s/cpus 0/cpuset.cpus 0/g" -e "s/mems 0/cpuset.mems 0/g" -i /vendor/etc/init/hw/init.target.performance.rc) || abort 9 "Couldn't fix-up init scripts!"

log "Disabling forced encryption in vendor fstab..."
sed "s/fileencryption/encryptable/" -i /vendor/etc/fstab.qcom || log "Couldn't disable forced encryption!"

log "Writing hybris-boot image..."
dd if=/tmp/hybris-boot.img of=/dev/block/bootdevice/by-name/boot || abort 10 "Couldn't write Hybris boot image!"

log "Cleaning up..."
umount /vendor &> /dev/null

# <<< Script end <<<

# Succeeded.
ui_print "            All done, enjoy your new OS!"
ui_print " "
exit 0