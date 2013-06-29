#!/sbin/busybox sh

BB=/sbin/busybox

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

$BB mount -o remount,rw /system;
$BB mount -t rootfs -o remount,rw rootfs;

cd /;

# copy cron files
$BB cp -a /res/crontab/ /data/;
$BB rm -rf /data/crontab/cron/ > /dev/null 2>&1;
if [ ! -e /data/crontab/custom_jobs ]; then
	$BB touch /data/crontab/custom_jobs;
	$BB chmod 777 /data/crontab/custom_jobs;
fi;

GMTWEAKS()
{

	if [ -f /system/app/STweaks.apk ]; then
		$BB rm -f /system/app/STweaks.apk > /dev/null 2>&1;
	fi;

	if [ -f /system/app/NXTweaks.apk ]; then
		stmd5sum=`$BB md5sum /system/app/NXTweaks.apk | $BB awk '{print $1}'`
		stmd5sum_kernel=`cat /res/nxtweaks_md5`;
		if [ "$stmd5sum" != "$stmd5sum_kernel" ]; then
			$BB rm -f /system/app/NXTweaks.apk > /dev/null 2>&1;
			$BB rm -f /data/app/com.gokhanmoral.*weaks*.apk > /dev/null 2>&1;
			$BB rm -f /data/dalvik-cache/*gokhanmoral.*weak*.apk* > /dev/null 2>&1;
			$BB rm -f /cache/dalvik-cache/*gokhanmoral.*weak*.apk* > /dev/null 2>&1;
		fi;
	fi;

	if [ ! -f /system/app/NXTweaks.apk ]; then
		$BB rm -f /data/app/com.gokhanmoral.*weak*.apk > /dev/null 2>&1;
		$BB rm -rf /data/data/com.gokhanmoral.*weak* > /dev/null 2>&1;
		$BB rm -f /data/dalvik-cache/*gokhanmoral.*weak*.apk* > /dev/null 2>&1;
		$BB rm -f /cache/dalvik-cache/*gokhanmoral.*weak*.apk* > /dev/null 2>&1;
		$BB cp -a /res/misc/payload/NXTweaks.apk /system/app/NXTweaks.apk;
		$BB chown 0.0 /system/app/NXTweaks.apk;
		$BB chmod 644 /system/app/NXTweaks.apk;
	fi;
}
GMTWEAKS;

EXTWEAKS_CLEAN()
{
	if [ -f /system/app/Extweaks.apk ] || [ -f /data/app/com.darekxan.extweaks.ap*.apk ]; then
		$BB rm -f /system/app/Extweaks.apk > /dev/null 2>&1;
		$BB rm -f /data/app/com.darekxan.extweaks.ap*.apk > /dev/null 2>&1;
		$BB rm -rf /data/data/com.darekxan.extweaks.app > /dev/null 2>&1;
		$BB rm -f /data/dalvik-cache/*com.darekxan.extweaks.app* > /dev/null 2>&1;
	fi;
}
EXTWEAKS_CLEAN;

# Create some free space
$BB rm -f /sbin/ext/efs-backup.sh > /dev/null 2>&1;
$BB rm -f /sbin/ext/pre-init.sh > /dev/null 2>&1;
$BB rm -f /res/nxtweaks_md5 > /dev/null 2>&1;
$BB rm -rf /res/misc > /dev/null 2>&1;
$BB rm -rf /res/images > /dev/null 2>&1;

$BB mount -t rootfs -o remount,rw rootfs;
$BB mount -o remount,rw /system;
