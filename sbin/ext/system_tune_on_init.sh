#!/sbin/busybox sh

# stop ROM VM from booting!
stop;

# set busybox location
BB=/sbin/busybox

$BB chmod -R 777 /tmp/;
$BB chmod 6755 /sbin/ext/*;

mount -o remount,rw,nosuid,nodev /cache;
mount -o remount,rw,nosuid,nodev /data;
mount -o remount,rw /;

# remount all partitions tweked settings
for m in $(mount | grep ext[3-4] | cut -d " " -f1); do
	mount -o remount,rw,noatime,nodiratime,noauto_da_alloc,discard,barrier=1,commit=10 $m;
done;

# cleaning
$BB rm -rf /cache/lost+found/* 2> /dev/null;
$BB rm -rf /data/lost+found/* 2> /dev/null;
$BB rm -rf /data/tombstones/* 2> /dev/null;
$BB rm -rf /data/anr/* 2> /dev/null;
$BB chmod -R 400 /data/tombstones;

# critical Permissions fix
$BB chmod -R 0777 /dev/cpuctl/;
$BB chmod -R 0777 /data/system/inputmethod/;
$BB chown -R root:system /sys/devices/system/cpu/;
$BB chmod -R 0777 /sys/devices/system/cpu/;
$BB chown -R system:system /data/anr;
$BB chmod -R 0777 /data/anr/;
$BB chmod 744 /proc/cmdline;

LOG_SDCARDS=/log-sdcards
FIX_BINARY=/sbin/fsck_msdos

SDCARD_FIX()
{
	# fixing sdcards
	$BB date > $LOG_SDCARDS;
	$BB echo "FIXING STORAGE" >> $LOG_SDCARDS;

	if [ -e /dev/block/mmcblk1p1 ]; then
		$BB echo "EXTERNAL SDCARD CHECK" >> $LOG_SDCARDS;
		$BB sh -c "$FIX_BINARY -p -f /dev/block/mmcblk1p1" >> $LOG_SDCARDS;
	else
		$BB echo "EXTERNAL SDCARD NOT EXIST" >> $LOG_SDCARDS;
	fi;

	$BB echo "INTERNAL SDCARD CHECK" >> $LOG_SDCARDS;
	$BB sh -c "$FIX_BINARY -p -f /dev/block/mmcblk0p11" >> $LOG_SDCARDS;
	$BB echo "DONE" >> $LOG_SDCARDS;
}

BOOT_ROM()
{
	# Start ROM VM boot!
	start;

	# start adb shell
	start adbd;
}

if [ -e /system/bin/fsck_msdos ]; then
	FIX_BINARY=/system/bin/fsck_msdos
	BOOT_ROM;
	SDCARD_FIX;
else
	BOOT_ROM;
	SDCARD_FIX;
fi;
