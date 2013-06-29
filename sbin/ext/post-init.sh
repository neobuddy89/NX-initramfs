#!/sbin/busybox sh

BB=/sbin/busybox

$BB mount -t rootfs -o remount,rw rootfs;
$BB mount -o remount,rw /system;

# first mod the partitions then boot
$BB sh /sbin/ext/system_tune_on_init.sh;

if [ ! -d /data/.siyah ]; then
	$BB mkdir -p /data/.siyah;
fi;

# reset config-backup-restore
if [ -f /data/.siyah/restore_running ]; then
	rm -f /data/.siyah/restore_running;
fi;

# set sysrq to 2 = enable control of console logging levelL
echo "2" > /proc/sys/kernel/sysrq;

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a$ccxmlsum" != "a`cat /data/.siyah/.ccxmlsum`" ]; then
	rm -f /data/.siyah/*.profile;
	echo "$ccxmlsum" > /data/.siyah/.ccxmlsum;
fi;

[ ! -f /data/.siyah/default.profile ] && cp -a /res/customconfig/default.profile /data/.siyah/default.profile;
[ ! -f /data/.siyah/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.siyah/battery.profile;
[ ! -f /data/.siyah/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.siyah/performance.profile;
[ ! -f /data/.siyah/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.siyah/extreme_performance.profile;
[ ! -f /data/.siyah/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.siyah/extreme_battery.profile;

$BB chmod -R 0777 /data/.siyah/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

# HACK: we have problem on boot with stuck service GoogleBackupTransport if many apps installed
# here i will rename the GoogleBackupTransport.apk to boot without it and then restore to prevent
# system not responding popup on after boot.
if [ -e /data/dalvik-cache/not_first_boot ]; then
	mount -o remount,rw /system;
	mv /system/app/GoogleBackupTransport.apk /system/app/GoogleBackupTransport.apk.off
fi;

(
# mdnie sharpness tweak
	if [ "$mdniemod" == "on" && "$hook_intercept" == "on" ]; then
		$BB sh /sbin/ext/mdnie-sharpness-tweak.sh;
		touch /data/.nx_mdniemodon;
		date > /data/.nx_mdniemodon;
	else
		if [ -e /data/.nx_mdniemodon ]; then
			rm /data/.nx_mdniemodon;
		fi
	fi;
	sleep 30;
	echo "$scenario" > /sys/class/mdnie/mdnie/scenario;
	echo "$mode" > /sys/class/mdnie/mdnie/mode;
)&

# dual core hotplug
echo "on" > /sys/devices/virtual/misc/second_core/hotplug_on;
echo "off" > /sys/devices/virtual/misc/second_core/second_core_on;

######################################
# Loading Modules
######################################
$BB chmod -R 755 /lib;

(
	sleep 50;
	$BB date > /data/nx_modules.log
	echo " " >>  /data/nx_modules.log;
	# order of modules load is important
	if [ "$j4fs_module" == "on" ]; then
		echo "Loading J4FS Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/j4fs.ko >> /data/nx_modules.log 2>&1;
		$BB mount -t j4fs /dev/block/mmcblk0p4 /mnt/.lfs
	fi;
	echo "Loading Si4709 Module" >> /data/nx_modules.log;
	$BB insmod /lib/modules/Si4709_driver.ko >> /data/nx_modules.log 2>&1;

	if [ "$usbserial_module" == "on" ]; then
		echo "Loading USB Serial Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/usbserial.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/ftdi_sio.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/pl2303.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$usbnet_module" == "on" ]; then
		echo "Loading USB Net Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/usbnet.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/asix.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$cifs_module" == "on" ]; then
		echo "Loading CIFS Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/cifs.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$eds_module" == "on" ]; then
		echo "Loading EDS Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/eds.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$xpad_module" == "on" ]; then
		echo "Loading XPAD Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/ff-memless.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/xpad.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$frandom_module" == "on" ]; then
		echo "Loading FRANDOM Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/frandom.ko >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/frandom >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/erandom >> /data/nx_modules.log 2>&1;
		mv /dev/random /dev/random.ori >> /data/nx_modules.log 2>&1;
		mv /dev/urandom /dev/urandom.ori >> /data/nx_modules.log 2>&1;
		ln /dev/frandom /dev/random >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/random >> /data/nx_modules.log 2>&1;
		ln /dev/erandom /dev/urandom >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/urandom >> /data/nx_modules.log 2>&1;
	fi;
	echo "First Run completed ...." >> /data/nx_modules.log;
	echo "         *******************" >> /data/nx_modules.log;
	sleep 50;
	echo " " >>  /data/nx_modules.log;
	echo "Second Run starts ...." >> /data/nx_modules.log;
	# order of modules load is important
	if [ "$j4fs_module" == "on" ]; then
		echo "Loading J4FS Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/j4fs.ko >> /data/nx_modules.log 2>&1;
		$BB mount -t j4fs /dev/block/mmcblk0p4 /mnt/.lfs
	fi;
	echo "Loading Si4709 Module" >> /data/nx_modules.log;
	$BB insmod /lib/modules/Si4709_driver.ko >> /data/nx_modules.log 2>&1;

	if [ "$usbserial_module" == "on" ]; then
		echo "Loading USB Serial Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/usbserial.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/ftdi_sio.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/pl2303.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$usbnet_module" == "on" ]; then
		echo "Loading USB Net Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/usbnet.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/asix.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$cifs_module" == "on" ]; then
		echo "Loading CIFS Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/cifs.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$eds_module" == "on" ]; then
		echo "Loading EDS Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/eds.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$xpad_module" == "on" ]; then
		echo "Loading XPAD Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/ff-memless.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/xpad.ko >> /data/nx_modules.log 2>&1;
	fi;
	date >> /data/nx_modules.log;
	echo " " >>  /data/nx_modules.log;
	echo " " >>  /data/nx_modules.log;
	echo "Loaded Modules on boot:" >> /data/nx_modules.log;
	echo " " >>  /data/nx_modules.log;
	$BB lsmod >> /data/nx_modules.log
)&

# enable kmem interface for everyone
echo "0" > /proc/sys/kernel/kptr_restrict;

# Cortex parent should be ROOT/INIT and not NXTweaks
nohup /sbin/ext/cortexbrain-tune.sh;

(
	# Run init.d scripts if chosen
	if [ $init_d == on ]; then
		$BB sh /sbin/ext/run-init-scripts.sh;
	fi;
)&

# disable debugging on some modules
if [ "$logger" == "off" ]; then
	echo "0" > /sys/module/ump/parameters/ump_debug_level;
	echo "0" > /sys/module/mali/parameters/mali_debug_level;
	echo "0" > /sys/module/kernel/parameters/initcall_debug;
#	echo "0" > /sys/module/lowmemorykiller/parameters/debug_level;
	echo "0" > /sys/module/cpuidle_exynos4/parameters/log_en;
	echo "0" > /sys/module/earlysuspend/parameters/debug_mask;
	echo "0" > /sys/module/alarm/parameters/debug_mask;
	echo "0" > /sys/module/alarm_dev/parameters/debug_mask;
	echo "0" > /sys/module/binder/parameters/debug_mask;
	echo "0" > /sys/module/xt_qtaguid/parameters/debug_mask;
fi;

# for ntfs automounting
mount -t tmpfs -o mode=0777,gid=1000 tmpfs /mnt/ntfs >> /data/.nx_ntfs 2>&1;

(
	# Apps Install
	$BB sh /sbin/ext/install.sh;

	# EFS Backup
	$BB sh /sbin/ext/efs-backup.sh;
)&

echo "0" > /tmp/uci_done;
chmod 666 /tmp/uci_done;

(
# custom boot booster
	COUNTER=0;
	while [ "`cat /tmp/uci_done`" != "1" ]; do
		if [ "$COUNTER" -ge "10" ]; then
			break;
		fi;
		pkill -f "com.gokhanmoral.stweaks.app";
		echo "Waiting For UCI to finish";
		sleep 10;
		COUNTER=$(($COUNTER+1));
	done;

	# restore normal freq and cpu core values
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	echo "$scheduler" > /sys/block/mmcblk0/queue/scheduler;


	# HACK: restore GoogleBackupTransport.apk after boot.
	if [ -e /data/dalvik-cache/not_first_boot ]; then
		mv /system/app/GoogleBackupTransport.apk.off /system/app/GoogleBackupTransport.apk
	else		
		/sbin/fix_permissions -l -r -v > /dev/null 2>&1;
		chmod 777 -R /system/etc/init.d
		touch /data/dalvik-cache/not_first_boot;
		chmod 777 /data/dalvik-cache/not_first_boot;
	fi;

	# ROOTBOX fix notification_wallpaper
	if [ -e /data/data/com.aokp.romcontrol/files/notification_wallpaper.jpg ]; then
		chmod 777 /data/data/com.aokp.romcontrol/files/notification_wallpaper.jpg
	fi;

	while [ ! `cat /proc/loadavg | cut -c1-4` \< "3.50" ]; do
		echo "Waiting For CPU to cool down";
		sleep 10;
	done;

	sync;
	sysctl -w vm.drop_caches=3
	sync;
	sysctl -w vm.drop_caches=1
	sync;
)&

(
	# stop uci.sh from running all the PUSH Buttons in stweaks on boot
	$BB mount -o remount,rw rootfs;
	$BB chown -R root:system /res/customconfig/actions/;
	$BB chmod -R 6755 /res/customconfig/actions/;
	$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;
	$BB chmod 6755 /res/no-push-on-boot/*;

	# change USB mode MTP or Mass Storage
	$BB sh /res/uci.sh usb-mode ${usb_mode};

	# apply NXTweaks settings
	echo "booting" > /data/.siyah/booting;
	chmod 777 /data/.siyah/booting;
	pkill -f "com.gokhanmoral.stweaks.app";
	nohup $BB sh /res/uci.sh restore;
	echo "1" > /tmp/uci_done;

	# restore all the PUSH Button Actions back to there location
	$BB mount -o remount,rw rootfs;
	$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
	pkill -f "com.gokhanmoral.stweaks.app";

	# update cpu tunig after profiles load
	# $BB sh /sbin/ext/cortexbrain-tune.sh apply_cpu update > /dev/null;
	$BB rm -f /data/.siyah/booting;

	DM=`ls -d /sys/block/loop*`;
	for i in ${DM}; do
		if [ -e $i/queue/rotational ]; then
			echo "0" > ${i}/queue/rotational;
		fi;
		if [ -e $i/queue/iostats ]; then
			echo "0" > ${i}/queue/iostats;
		fi;
		if [ -e $i/queue/nr_requests ]; then
			echo "1024" > ${i}/queue/nr_requests;
		fi;
	done;

	mount -o remount,rw /system;
	mount -o remount,rw /;

	setprop persist.sys.scrollingcache 3
	setprop windowsmgr.max_events_per_sec 300
	setprop ro.max.fling_velocity 12000
	setprop ro.min.fling_velocity 8000

	# correct oom tuning, if changed by apps/rom
	$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
	$BB sh /res/uci.sh oom_config_screen_off $oom_config_screen_off;

	# correct mDNIe mode and scenario
	pkill -f "com.cyanogenmod.settings.device";
	echo "$scenario" > /sys/class/mdnie/mdnie/scenario;
	echo "$mode" > /sys/class/mdnie/mdnie/mode;
	echo "$pwm_val" > /sys/vibrator/pwm_val;

	echo "Done Booting" > /data/nx-boot-check;
	date >> /data/nx-boot-check;
)&
