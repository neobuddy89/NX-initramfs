#!/sbin/busybox sh

BB=/sbin/busybox

# set "/" rw
$BB mount -o remount,rw rootfs;
$BB mount -t ext4 /dev/block/mmcblk0p9 /system;

# linking /system/bin to /bin for crond
ln -s /system/bin /bin
ln -s /system/lib /lib

# fix permissions for tmp init files
$BB chown -R root:system /tmp/;
$BB chmod -R 777 /tmp/;
$BB chmod 6755 /sbin/ext/*;
$BB chmod -R 777 /res/;

rm -rf /res/dev;
mkdir -p /res/dev;

# network tuning reset to allow real ROM control over H/H+/3G/G signal.
$BB sed -i "s/ro.ril.hsxpa=[0-9]*//g" /system/build.prop;
$BB sed -i "s/ro.ril.gprsclass=[0-9]*//g" /system/build.prop;

# system dalvik.vm tuning.
$BB sed -i "s/dalvik.vm.heapsize=[0-9a-zA-Z]*/dalvik.vm.heapsize=128m/g" /system/build.prop;
$BB sed -i "s/dalvik.vm.heapstartsize=[0-9a-zA-Z]*/dalvik.vm.heapstartsize=16m/g" /system/build.prop;
$BB sed -i "s/dalvik.vm.heapgrowthlimit=[0-9a-zA-Z]*/dalvik.vm.heapgrowthlimit=64m/g" /system/build.prop;

PARTITION_TUNING()
{
	DEVICE_DATA="/dev/block/mmcblk0p10";
	DIR_DATA="/data";
	LOG_DATA="/log-data";
	LOG_DATA_TMP="/log-data-tmp";

	DEVICE_CACHE="/dev/block/mmcblk0p7";
	DIR_CACHE="/cache";
	LOG_CACHE="/log-cache";
	LOG_CACHE_TMP="/log-cache-tmp";

	# new empty log
	$BB sh -c "/sbin/date" > $LOG_DATA;
	$BB sh -c "/sbin/date" > $LOG_CACHE;

	# umount 
	$BB umount -l $DIR_DATA >> $LOG_DATA 2>&1;
	$BB umount -l $DIR_CACHE >> $LOG_CACHE 2>&1;

	# triggers
	NEED_CHECK_CACHE=0;
	NEED_CHECK_DATA=0;

	# set fs-feature -> [^]has_journal
	$BB sh -c "/sbin/tune2fs -l $DEVICE_CACHE | grep 'features' | grep 'has_journal'" > $LOG_CACHE_TMP;
	if [ "a`cat $LOG_CACHE_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -O ^has_journal $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
		NEED_CHECK_CACHE=1;
	fi;
	$BB sh -c "/sbin/tune2fs -l $DEVICE_DATA | grep 'features' | grep 'has_journal'" > $LOG_DATA_TMP;
	if [ "a`cat $LOG_DATA_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -O ^has_journal $DEVICE_DATA" >> $LOG_DATA 2>&1;
		NEED_CHECK_DATA=1;
	fi;

	# set fs-feature -> [^]dir_index
	$BB sh -c "/sbin/tune2fs -l $DEVICE_CACHE | grep 'features' | grep 'dir_index'" > $LOG_CACHE_TMP;
	if [ "a`cat $LOG_CACHE_TMP`" == "a" ]; then	
		$BB sh -c "/sbin/tune2fs -O dir_index $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
		NEED_CHECK_CACHE=1;
	fi;
	$BB sh -c "/sbin/tune2fs -l $DEVICE_DATA | grep 'features' | grep 'dir_index'" > $LOG_DATA_TMP;
	if [ "a`cat $LOG_DATA_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -O dir_index $DEVICE_DATA" >> $LOG_DATA 2>&1;
		NEED_CHECK_DATA=1;
	fi;

	# check if journal recover needed
	$BB sh -c "/sbin/tune2fs -l $DEVICE_CACHE | grep 'features' | grep 'needs_recovery'" > $LOG_CACHE_TMP;
	if [ "a`cat $LOG_CACHE_TMP`" == "a" ]; then
		NEED_CHECK_CACHE=1;
	fi;
	$BB sh -c "/sbin/tune2fs -l $DEVICE_DATA | grep 'features' | grep 'needs_recovery'" > $LOG_DATA_TMP;
	if [ "a`cat $LOG_DATA_TMP`" == "a" ]; then
		NEED_DATA_CACHE=1;
	fi;

	# set mount option -> [^]journal_data_writeback
	$BB sh -c "/sbin/tune2fs -l $DEVICE_CACHE | grep 'Default mount options' | grep 'journal_data_writeback'" > $LOG_CACHE_TMP;
	if [ "a`cat $LOG_CACHE_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -o journal_data_writeback $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
		NEED_CHECK_CACHE=1;
	fi;
	$BB sh -c "/sbin/tune2fs -l $DEVICE_DATA | grep 'Default mount options' | grep 'journal_data_writeback'" > $LOG_DATA_TMP;
	if [ "a`cat $LOG_DATA_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -o journal_data_writeback $DEVICE_DATA" >> $LOG_DATA 2>&1;
		NEED_CHECK_DATA=1;
	fi;

	# set inode to 256
	$BB sh -c "/sbin/tune2fs -l $DEVICE_CACHE | grep 'Inode size' | grep '256'" > $LOG_CACHE_TMP;
	if [ "a`cat $LOG_CACHE_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -I 256 $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
	fi;
	$BB sh -c "/sbin/tune2fs -l $DEVICE_DATA | grep 'Inode size' | grep '256'" > $LOG_DATA_TMP;
	if [ "a`cat $LOG_DATA_TMP`" == "a" ]; then
		$BB sh -c "/sbin/tune2fs -I 256 $DEVICE_DATA" >> $LOG_DATA 2>&1;
	fi;

	# check 'X2' partitions, if needed
	if [ "$NEED_CHECK_CACHE" == "1" ]; then
		$BB sh -c "/sbin/e2fsck -p $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
		$BB sh -c "/sbin/e2fsck -p $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
	fi;
	if [ "$NEED_CHECK_DATA" == "1" ]; then
		$BB sh -c "/sbin/e2fsck -p $DEVICE_DATA" >> $LOG_DATA 2>&1;
		$BB sh -c "/sbin/e2fsck -p $DEVICE_DATA" >> $LOG_DATA 2>&1;
	fi;

	# efs check and fix, do not change
	$BB sh -c "/sbin/e2fsck -fyc /dev/block/mmcblk0p1" > /tmp/efs_check;
	$BB sh -c "/sbin/e2fsck -p /dev/block/mmcblk0p1" >> /tmp/efs_check 2>&1;

	# only if asked by user via stweaks
	if [ -e /system/run_fs_check ]; then
		# reset the lock-file
		$BB rm -f /system/run_fs_check;

		# check cache
		$BB sh -c "/sbin/e2fsck -fyc $DEVICE_CACHE"
		$BB sh -c "/sbin/e2fsck -fyc $DEVICE_CACHE" >> $LOG_CACHE 2>&1;
		$BB sh -c "/sbin/e2fsck -p $DEVICE_CACHE" >> $LOG_CACHE 2>&1;

		# check data
		$BB sh -c "/sbin/e2fsck -fyc $DEVICE_DATA"
		$BB sh -c "/sbin/e2fsck -fyc $DEVICE_DATA" >> $LOG_DATA 2>&1;
		$BB sh -c "/sbin/e2fsck -p $DEVICE_DATA" >> $LOG_DATA 2>&1;

		$BB mount -t ext4 $DEVICE_DATA /data;
		$BB rm -f /data/dalvik-cache/*;
		sync;
		umount /data;
	fi;
}

if [ -e /dev/block/mmcblk1p1 ]; then
	mkdir -p /mnt/tmp2;
	$BB mount -t vfat /dev/block/mmcblk1p1 /mnt/tmp2 && ( mkdir -p /mnt/tmp2/clockworkmod/blobs/ ) && ( touch /mnt/tmp2/clockworkmod/.nomedia ) && ( touch /mnt/tmp2/clockworkmod/blobs/.nomedia );
	touch /tmp/sdcard_size;
	echo "4" > /tmp/sdcard_size;
	SDCARD_SIZE=`$BB df | $BB grep /dev/block/mmcblk1p1 | $BB cut -c 23-30`
	if [ "$SDCARD_SIZE" -lt "1000000" ]; then
		echo "1" > /tmp/sdcard_size;
	elif [ "$SDCARD_SIZE" -lt "4000000" ]; then
		echo "4" > /tmp/sdcard_size;
	elif [ "$SDCARD_SIZE" -lt "8000000" ]; then
		echo "8" > /tmp/sdcard_size;
	elif [ "$SDCARD_SIZE" -lt "16000000" ]; then
		echo "16" > /tmp/sdcard_size;
	elif [ "$SDCARD_SIZE" -lt "32000000" ]; then
		echo "32" > /tmp/sdcard_size;
	elif [ "$SDCARD_SIZE" -lt "64000000" ]; then
		echo "64" > /tmp/sdcard_size;
	fi;
	$BB umount -l /mnt/tmp2;
fi;
PARTITION_TUNING;

# make space
rm -f /sbin/tune2fs;
rm -f /sbin/e2fsck;
# ln -s /system/xbin/busybox /sbin/tune2fs;
# ln -s /system/xbin/e2fsck /sbin/e2fsck;
ln -s /system/xbin/kmemhelper /sbin/kmemhelper;
ln -s /system/xbin/mke2fs /sbin/mke2fs;
# ln -s /system/xbin/busybox /sbin/swapon;
ln -s /system/xbin/parted /sbin/parted;

sync;
$BB umount -l /system;
