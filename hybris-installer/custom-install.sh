#!/sbin/sh
# This is a custom Hybris Installer script made by me.

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
[ -f /vendor/etc/init/hw/init.qcom.rc ] || abort 5 "Please install LineageOS before flashing this zip."

# <<< Sanity checks <<<

# >>> Script start >>>

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
ui_print "    Sailfish OS release to be installed: %VERSION%"
ui_print "                   Please wait ..."

# Script

# TODO Fall back to swapfile if failed
log "Patching TWRP's broken tar..."
(cp /tmp/tar /sbin/tar && chmod 777 /sbin/tar) || abort 6 "Couldn't patch tar!"

log "Extracting SFOS rootfs..."
FS_ARC="/tmp/sailfishos-rootfs.tar.bz2"
FS_DST="/data/.stowaways/sailfishos/"
rm -rf $FS_DST
mkdir -p $FS_DST
tar --numeric-owner -xvjf $FS_ARC -C $FS_DST || abort 7 "Couldn't extract SFOS rootfs!"
rm $FS_ARC

log "Disabling qti & time_daemon by default..."
(sed -i "s/service qti.*/service qti \/vendor\/bin\/qti_HYBRIS_DISABLED/" /vendor/etc/init/hw/init.qcom.rc && sed -i "s/service time_daemon.*/service time_daemon \/vendor\/bin\/time_daemon_HYBRIS_DISABLED/" /vendor/etc/init/hw/init.qcom.rc) || log "Disabling qti & time_daemon failed!"

log "Disabling forced encryption in vendor fstab..."
sed -i "s/fileencryption/encryptable/" /vendor/etc/fstab.qcom || log "Disabling forced encryption failed!"

log "Writing hybris-boot image..."
dd if=/tmp/hybris-boot.img of=/dev/block/sde19 || abort 8 "Couldn't write Hybris boot image!"

log "Cleaning up..."
umount /vendor &> /dev/null

# <<< Script end <<<

# Succeeded.
ui_print "            All done, enjoy your new OS!"
ui_print " "
exit 0