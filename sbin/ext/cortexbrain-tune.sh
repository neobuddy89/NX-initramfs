#!/sbin/busybox sh

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
#
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# change mode for /tmp/
chmod -R 1777 /tmp/;

# ==============================================================
# GLOBAL VARIABLES || without "local" also a variable in a function is global
# ==============================================================

FILE_NAME=$0;
PIDOFCORTEX=$$;
# (since we don't have the recovery source code I can't change the ".siyah" dir, so just leave it there for history)
DATA_DIR=/data/.siyah;
WAS_IN_SLEEP_MODE=1;
NOW_CALL_STATE=0;
USB_POWER=0;
# read sd-card size, set via boot
SDCARD_SIZE=`cat /tmp/sdcard_size`;

# ==============================================================
# INITIATE
# ==============================================================

# get values from profile
PROFILE=`cat $DATA_DIR/.active.profile`;
. $DATA_DIR/${PROFILE}.profile;

# check if dumpsys exist in ROM
if [ -e /system/bin/dumpsys ]; then
	DUMPSYS_STATE=1;
else
	DUMPSYS_STATE=0;
fi;

# set initial vm.dirty vales
echo "500" > /proc/sys/vm/dirty_writeback_centisecs;
echo "1000" > /proc/sys/vm/dirty_expire_centisecs;

# ==============================================================
# FILES FOR VARIABLES || we need this for write variables from child-processes to parent
# ==============================================================

# WIFI HELPER
WIFI_HELPER_AWAKE="$DATA_DIR/WIFI_HELPER_AWAKE";
WIFI_HELPER_TMP="$DATA_DIR/WIFI_HELPER_TMP";
echo "1" > $WIFI_HELPER_TMP;

# MOBILE HELPER
MOBILE_HELPER_AWAKE="$DATA_DIR/MOBILE_HELPER_AWAKE";
MOBILE_HELPER_TMP="$DATA_DIR/MOBILE_HELPER_TMP";
echo "1" > $MOBILE_HELPER_TMP;

# ==============================================================
# I/O-TWEAKS 
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == on ]; then

		local i="";

		local ZRM=`ls -d /sys/block/zram*`;
		for i in $ZRM; do
			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/rq_affinity ]; then
				echo "1" > $i/queue/rq_affinity;
			fi;
		done;

		local MMC=`ls -d /sys/block/mmc*`;
		for i in $MMC; do
			if [ -e $i/queue/scheduler ]; then
				echo $scheduler > $i/queue/scheduler;
			fi;

			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/nr_requests ]; then
				echo "1024" > $i/queue/nr_requests; # default: 128
			fi;
		done;

		# our storage is 16GB, best is 1024KB readahead
		echo "1024" > /sys/block/mmcblk0/queue/read_ahead_kb;

		if [ -e /sys/block/mmcblk1/queue/read_ahead_kb ]; then
			if [ "$cortexbrain_read_ahead_kb" -eq "0" ]; then

				if [ "$SDCARD_SIZE" -eq "1" ]; then
					echo "256" > /sys/block/mmcblk1/queue/read_ahead_kb;
				elif [ "$SDCARD_SIZE" -eq "4" ]; then
					echo "512" > /sys/block/mmcblk1/queue/read_ahead_kb;
				elif [ "$SDCARD_SIZE" -eq "8" ] || [ "$SDCARD_SIZE" -eq "16" ]; then
					echo "1024" > /sys/block/mmcblk1/queue/read_ahead_kb;
				elif [ "$SDCARD_SIZE" -eq "32" ]; then
					echo "2048" > /sys/block/mmcblk1/queue/read_ahead_kb;
				elif [ "$SDCARD_SIZE" -eq "64" ]; then
					echo "2560" > /sys/block/mmcblk1/queue/read_ahead_kb;
				fi;

			else
				echo "$cortexbrain_read_ahead_kb" > /sys/block/mmcblk1/queue/read_ahead_kb;
			fi;
		fi;

		echo "45" > /proc/sys/fs/lease-break-time;

		log -p i -t $FILE_NAME "*** IO_TWEAKS ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
IO_TWEAKS;

# ==============================================================
# KERNEL-TWEAKS
# ==============================================================
KERNEL_TWEAKS()
{
	local state="$1";

	if [ "$cortexbrain_kernel_tweaks" == on ]; then

		if [ "$state" == "awake" ]; then
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "120" > /proc/sys/kernel/panic;
		elif [ "$state" == "sleep" ]; then
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "90" > /proc/sys/kernel/panic;
		else
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "120" > /proc/sys/kernel/panic;
		fi;

		if [ "$cortexbrain_memory" == on ]; then
			echo "32 32" > /proc/sys/vm/lowmem_reserve_ratio;
		fi;

		log -p i -t $FILE_NAME "*** KERNEL_TWEAKS ***: $state ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
KERNEL_TWEAKS;

# ==============================================================
# SYSTEM-TWEAKS
# ==============================================================
SYSTEM_TWEAKS()
{
	if [ "$cortexbrain_system" == on ]; then
		setprop hwui.render_dirty_regions false;
		setprop windowsmgr.max_events_per_sec 300;
		setprop profiler.force_disable_err_rpt 1;
		setprop profiler.force_disable_ulog 1;

		log -p i -t $FILE_NAME "*** SYSTEM_TWEAKS ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
SYSTEM_TWEAKS;

# ==============================================================
# BATTERY-TWEAKS
# ==============================================================
BATTERY_TWEAKS()
{
	if [ "$cortexbrain_battery" == on ]; then

		# battery-calibration if battery is full
		local LEVEL=`cat /sys/class/power_supply/battery/capacity`;
		local CURR_ADC=`cat /sys/class/power_supply/battery/batt_current_adc`;
		local BATTFULL=`cat /sys/class/power_supply/battery/batt_full_check`;
		loacl i="";
		local bus="";

		log -p i -t $FILE_NAME "*** BATTERY - LEVEL: $LEVEL - CUR: $CURR_ADC ***";

		if [ "$LEVEL" -eq "100" ] && [ "$BATTFULL" -eq "1" ]; then
			rm -f /data/system/batterystats.bin;
			log -p i -t $FILE_NAME "battery-calibration done ...";
		fi;

		# LCD: power-reduce
		if [ -e /sys/class/lcd/panel/power_reduce ]; then
			if [ "$power_reduce" == on ]; then
				echo "1" > /sys/class/lcd/panel/power_reduce;
			else
				echo "0" > /sys/class/lcd/panel/power_reduce;
			fi;
		fi;

		# USB: power support
		local POWER_LEVEL=`ls /sys/bus/usb/devices/*/power/control`;
		for i in $POWER_LEVEL; do
			chmod 777 $i;
			echo "auto" > $i;
		done;

		local POWER_AUTOSUSPEND=`ls /sys/bus/usb/devices/*/power/autosuspend`;
		for i in $POWER_AUTOSUSPEND; do
			chmod 777 $i;
			echo "1" > $i;
		done;

		# BUS: power support
		local buslist="spi i2c sdio";
		for bus in $buslist; do
			local POWER_CONTROL=`ls /sys/bus/$bus/devices/*/power/control`;
			for i in $POWER_CONTROL; do
				chmod 777 $i;
				echo "auto" > $i;
			done;
		done;

		log -p i -t $FILE_NAME "*** BATTERY_TWEAKS ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
# run this tweak once, if the background-process is disabled
if [ "$cortexbrain_background_process" -eq "0" ]; then
	BATTERY_TWEAKS;
fi;

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == on ]; then
		echo "$dirty_background_ratio" > /proc/sys/vm/dirty_background_ratio; # default: 10
		echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio; # default: 20
		echo "4" > /proc/sys/vm/min_free_order_shift; # default: 4
		echo "1" > /proc/sys/vm/overcommit_memory; # default: 1
		echo "950" > /proc/sys/vm/overcommit_ratio; # default: 50
		echo "3" > /proc/sys/vm/page-cluster; # default: 3
		echo "8192" > /proc/sys/vm/min_free_kbytes;
		echo "16384" > /proc/sys/vm/mmap_min_addr;

		log -p i -t $FILE_NAME "*** MEMORY_TWEAKS ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
MEMORY_TWEAKS;

# ==============================================================
# TCP-TWEAKS
# ==============================================================
TCP_TWEAKS()
{
	if [ "$cortexbrain_tcp" == on ]; then
		echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
		echo "1" > /proc/sys/net/ipv4/tcp_sack;
		echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
		echo "1" > /proc/sys/net/ipv4/tcp_window_scaling;
		echo "1" > /proc/sys/net/ipv4/tcp_moderate_rcvbuf;
		echo "1" > /proc/sys/net/ipv4/route/flush;
		echo "2" > /proc/sys/net/ipv4/tcp_syn_retries;
		echo "2" > /proc/sys/net/ipv4/tcp_synack_retries;
		echo "10" > /proc/sys/net/ipv4/tcp_fin_timeout;
		echo "0" > /proc/sys/net/ipv4/tcp_ecn;
		echo "3" > /proc/sys/net/ipv4/tcp_keepalive_probes;
		echo "20" > /proc/sys/net/ipv4/tcp_keepalive_intvl;

		log -p i -t $FILE_NAME "*** TCP_TWEAKS ***: enabled";
	fi;

	if [ "$cortexbrain_tcp_ram" == on ]; then
		echo "1048576" > /proc/sys/net/core/wmem_max;
		echo "1048576" > /proc/sys/net/core/rmem_max;
		echo "262144" > /proc/sys/net/core/rmem_default;
		echo "262144" > /proc/sys/net/core/wmem_default;
		echo "20480" > /proc/sys/net/core/optmem_max;
		echo "262144 524288 1048576" > /proc/sys/net/ipv4/tcp_wmem;
		echo "262144 524288 1048576" > /proc/sys/net/ipv4/tcp_rmem;
		echo "4096" > /proc/sys/net/ipv4/udp_rmem_min;
		echo "4096" > /proc/sys/net/ipv4/udp_wmem_min;

		log -p i -t $FILE_NAME "*** TCP_RAM_TWEAKS ***: enabled";
	fi;
}
TCP_TWEAKS;

# ==============================================================
# FIREWALL-TWEAKS
# ==============================================================
FIREWALL_TWEAKS()
{
	if [ "$cortexbrain_firewall" == on ]; then
		# ping/icmp protection
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts;
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all;
		echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses;

		log -p i -t $FILE_NAME "*** FIREWALL_TWEAKS ***: enabled";

		return 1;
	else
		return 0;
	fi;
}
FIREWALL_TWEAKS;

# ==============================================================
# UKSM-TWEAKS
# ==============================================================

UKSMCTL()
{
	local state="$1";
	local uksm_run_tmp="/sys/kernel/mm/uksm/run";
	if [ ! -e $uksm_run_tmp ]; then
		uksm_run_tmp="/dev/null";
	fi;

	if [ "$cortexbrain_uksm_control" == on ] && [ "$uksm_run_tmp" != "/dev/null" ]; then
		echo "1" > $uksm_run_tmp;
		renice -n 10 -p `pidof uksmd`;

		if [ "$state" == "awake" ]; then
			echo "500" > /sys/kernel/mm/uksm/sleep_millisecs; # max: 1000
			echo "medium" > /sys/kernel/mm/uksm/cpu_governor;

			log -p i -t $FILE_NAME "*** uksm: awake, sleep=0,5sec, max_cpu=50% ***";

		elif [ "$state" == "sleep" ]; then
			echo "1000" > /sys/kernel/mm/uksm/sleep_millisecs; # max: 1000
			echo "quiet" > /sys/kernel/mm/uksm/cpu_governor;

			log -p i -t $FILE_NAME "*** uksm: sleep, sleep=1sec, max_cpu=1% ***";
		fi;
	else
		echo "0" > $uksm_run_tmp;
	fi;
}

# ==============================================================
# GLOBAL-FUNCTIONS
# ==============================================================

WIFI_SET()
{
	local state="$1";
	
	if [ "$state" == "off" ]; then
		service call wifi 13 i32 0 > /dev/null;
		svc wifi disable;
		echo "1" > $WIFI_HELPER_AWAKE;
	elif [ "$state" == "on" ]; then
		service call wifi 13 i32 1 > /dev/null;
		svc wifi enable;
	fi;

	log -p i -t $FILE_NAME "*** WIFI ***: $state";
}

WIFI()
{
	local state="$1";

	if [ "$state" == "sleep" ]; then
		if [ "$cortexbrain_auto_tweak_wifi" == on ]; then
			if [ -e /sys/module/dhd/initstate ]; then
				if [ "$cortexbrain_auto_tweak_wifi_sleep_delay" -eq "0" ]; then
					WIFI_SET "off";
				else
					(
						echo "0" > $WIFI_HELPER_TMP;
						# screen time out but user want to keep it on and have wifi
						sleep 10;
						if [ `cat $WIFI_HELPER_TMP` -eq "0" ]; then
							# user did not turned screen on, so keep waiting
							local SLEEP_TIME_WIFI=$(( $cortexbrain_auto_tweak_wifi_sleep_delay - 10 ));
							log -p i -t $FILE_NAME "*** DISABLE_WIFI $cortexbrain_auto_tweak_wifi_sleep_delay Sec Delay Mode ***";
							sleep $SLEEP_TIME_WIFI;
							if [ `cat $WIFI_HELPER_TMP` -eq "0" ]; then
								# user left the screen off, then disable wifi
								WIFI_SET "off";
							fi;
						fi;
					)&
				fi;
			else
				echo "0" > $WIFI_HELPER_AWAKE;
			fi;
		fi;
	elif [ "$state" == "awake" ]; then
		if [ "$cortexbrain_auto_tweak_wifi" == on ]; then
			echo "1" > $WIFI_HELPER_TMP;
			if [ `cat $WIFI_HELPER_AWAKE` -eq "1" ]; then
				WIFI_SET "on";
			fi;
		fi;
	fi;
}

MOBILE_DATA_SET()
{
	local state="$1";

	if [ "$state" == "off" ]; then
		svc data disable;
		echo "1" > $MOBILE_HELPER_AWAKE;
	elif [ "$state" == "on" ]; then
		svc data enable;
	fi;

	log -p i -t $FILE_NAME "*** MOBILE DATA ***: $state";
}

MOBILE_DATA_STATE()
{
	DATA_STATE_CHECK=0;

	if [ $DUMPSYS_STATE -eq "1" ]; then
		local DATA_STATE=`echo "$TELE_DATA" | awk '/mDataConnectionState/ {print $1}'`;

		if [ "$DATA_STATE" != "mDataConnectionState=0" ]; then
			DATA_STATE_CHECK=1;
		fi;
	fi;
}

MOBILE_DATA()
{
	local state="$1";

	if [ "$cortexbrain_auto_tweak_mobile" == on ]; then
		if [ "$state" == "sleep" ]; then
			MOBILE_DATA_STATE;
			if [ "$DATA_STATE_CHECK" -eq "1" ]; then
				if [ "$cortexbrain_auto_tweak_mobile_sleep_delay" -eq "0" ]; then
					MOBILE_DATA_SET "off";
				else
					(
						echo "0" > $MOBILE_HELPER_TMP;
						# screen time out but user want to keep it on and have mobile data
						sleep 10;
						if [ `cat $MOBILE_HELPER_TMP` -eq "0" ]; then
							# user did not turned screen on, so keep waiting
							local SLEEP_TIME_DATA=$(( $cortexbrain_auto_tweak_mobile_sleep_delay - 10 ));
							log -p i -t $FILE_NAME "*** DISABLE_MOBILE $cortexbrain_auto_tweak_mobile_sleep_delay Sec Delay Mode ***";
							sleep $SLEEP_TIME_DATA;
							if [ `cat $MOBILE_HELPER_TMP` -eq "0" ]; then
								# user left the screen off, then disable mobile data
								MOBILE_DATA_SET "off";
							fi;
						fi;
					)&
				fi;
			else
				echo "0" > $MOBILE_HELPER_AWAKE;
			fi;
		elif [ "$state" == "awake" ]; then
			echo "1" > $MOBILE_HELPER_TMP;
			if [ `cat $MOBILE_HELPER_AWAKE` -eq "1" ]; then
				MOBILE_DATA_SET "on";
			fi;
		fi;
	fi;
}

LOGGER()
{
	local state="$1";
	local dev_log_sleep="/dev/log-sleep";
	local dev_log="/dev/log";

	if [ "$state" == "awake" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == debug ]; then
			if [ -e $dev_log_sleep ] && [ ! -e $dev_log ]; then
				mv $dev_log_sleep $dev_log
			fi;
		fi;
	elif [ "$state" == "sleep" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == disabled ]; then
			if [ -e $dev_log ]; then
				mv $dev_log $dev_log_sleep;
			fi;
		fi;
	fi;

	log -p i -t $FILE_NAME "*** LOGGER ***: $state";
}

# mount sdcard and emmc, if usb mass storage is used
MOUNT_SD_CARD()
{
	if [ "$auto_mount_sd" == on ]; then
		echo "/dev/block/vold/259:3" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun0/file;
		if [ -e /dev/block/vold/179:25 ]; then
			echo "/dev/block/vold/179:25" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
		fi;
		if [ -e /dev/block/vold/179:9 ]; then
			echo "/dev/block/vold/179:9" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
		fi;

		log -p i -t $FILE_NAME "*** MOUNT_SD_CARD ***";
	fi;
}

MALI_TIMEOUT()
{
	local state="$1";

	if [ "$state" == "awake" ]; then
		echo "$mali_gpu_utilization_timeout" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	elif [ "$state" == "sleep" ]; then
		echo "1000" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	elif [ "$state" == "wake_boost" ]; then
		echo "250" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	fi;

	log -p i -t $FILE_NAME "*** MALI_TIMEOUT: $state ***";
}

# set swappiness in case that no root installed, and zram used or disk swap used
SWAPPINESS()
{
	local SWAP_CHECK=`free | grep Swap | awk '{ print $2 }'`;

	if [ "$SWAP_CHECK" -eq "0" ]; then
		echo "0" > /proc/sys/vm/swappiness;
	else
		echo "$swappiness" > /proc/sys/vm/swappiness;
	fi;

	log -p i -t $FILE_NAME "*** SWAPPINESS: $swappiness ***";
}
SWAPPINESS;

# disable/enable ipv6  
IPV6()
{
	local state='';

	if [ -e /data/data/com.cisco.anyconnec* ]; then
		local CISCO_VPN=1;
	else
		local CISCO_VPN=0;
	fi;

	if [ "$cortexbrain_ipv6" == on ] || [ "$CISCO_VPN" -eq "1" ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null;
		local state="enabled";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null;
		local state="disabled";
	fi;

	log -p i -t $FILE_NAME "*** IPV6 ***: $state";
}

NET()
{
	local state="$1";

	if [ "$state" == "awake" ]; then
		echo "3" > /proc/sys/net/ipv4/tcp_keepalive_probes; # default: 3
		echo "1200" > /proc/sys/net/ipv4/tcp_keepalive_time; # default: 7200s
		echo "10" > /proc/sys/net/ipv4/tcp_keepalive_intvl; # default: 75s
		echo "10" > /proc/sys/net/ipv4/tcp_retries2; # default: 15
	elif [ "$state" == "sleep" ]; then
		echo "2" > /proc/sys/net/ipv4/tcp_keepalive_probes;
		echo "300" > /proc/sys/net/ipv4/tcp_keepalive_time;
		echo "5" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
		echo "5" > /proc/sys/net/ipv4/tcp_retries2;
	fi;

	log -p i -t $FILE_NAME "*** NET ***: $state";
}

CROND_SAFETY()
{
	if [ "$crontab" == on ]; then
		pkill -f "crond";
		/res/crontab_service/service.sh;

		log -p i -t $FILE_NAME "*** CROND_SAFETY ***";

		return 1;
	else
		return 0;
	fi;
}

OVERRIDE_PROTECTION()
{
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	echo "$pwm_val" > /sys/vibrator/pwm_val;
	echo "$epen_hand" > /sys/class/sec/sec_epen/epen_hand;
	echo "$tsp_threshold" > /sys/class/sec/sec_touchscreen/tsp_threshold;
	log -p i -t $FILE_NAME "*** OVERRIDE_PROTECTION ***";

	return 1;
}

ENABLEMASK()
{
	local state="$1";
	local enable_mask_tmp="/sys/module/cpuidle_exynos4/parameters/enable_mask";
	if [ -e $enable_mask_tmp ]; then
		enable_mask_tmp="/dev/null";
	fi;

	local tmp_enable_mask=`cat $enable_mask_tmp`;

	if [ "$state" == "awake" ]; then
		if [ "$tmp_enable_mask" != "$enable_mask" ]; then
			echo "$enable_mask" > $enable_mask_tmp;
		fi;
	elif [ "$state" == "sleep" ]; then
		if [ "$tmp_enable_mask" != "$enable_mask_sleep" ]; then
			echo "$enable_mask_sleep" > $enable_mask_tmp;
		fi;
	fi;

	log -p i -t $FILE_NAME "*** ENABLEMASK: $state ***: done";
}

IO_SCHEDULER()
{
	if [ "$cortexbrain_io" == on ]; then

		local state="$1";
		local sys_mmc0_scheduler_tmp="/sys/block/mmcblk0/queue/scheduler";
		local sys_mmc1_scheduler_tmp="/sys/block/mmcblk1/queue/scheduler";
		local tmp_scheduler="";
		local new_scheduler="";

		if [ -e $sys_mmc1_scheduler_tmp ]; then
			sys_mmc1_scheduler_tmp="/dev/null";
		fi;

		if [ "$state" == "awake" ]; then
			new_scheduler=$scheduler;
		elif [ "$state" == "sleep" ]; then
			new_scheduler=$sleep_scheduler
		fi;

		tmp_scheduler=`cat $sys_mmc0_scheduler_tmp`;

		if [ "$tmp_scheduler" != "$new_scheduler" ]; then
			echo "$new_scheduler" > $sys_mmc0_scheduler_tmp;
			echo "$new_scheduler" > $sys_mmc1_scheduler_tmp;
		fi;

		log -p i -t $FILE_NAME "*** IO_SCHEDULER: $state - $new_scheduler ***: done";

		# set I/O Tweaks again ...
		IO_TWEAKS;
	else
		log -p i -t $FILE_NAME "*** Cortex IO_SCHEDULER: Disabled ***";
	fi;
}

CPU_AUTOPLUG()
{
	local state="$1";
	local cpu_mode="Disabled";
	if [ "$cortexbrain_autoplug" == on ]; then
		if [ "$state" == "awake" ]; then
			cpu_mode="Dynamic";
			echo "on" > /sys/devices/virtual/misc/second_core/hotplug_on;
			echo "off" > /sys/devices/virtual/misc/second_core/second_core_on;
		elif [ "$state" == "sleep" ]; then
			cpu_mode="Single-Core";
			echo "off" > /sys/devices/virtual/misc/second_core/hotplug_on;
			echo "off" > /sys/devices/virtual/misc/second_core/second_core_on;
		elif [ "$state" == "wake_boost" ]; then
			cpu_mode="Dual-Core";
			echo "off" > /sys/devices/virtual/misc/second_core/hotplug_on;
			echo "on" > /sys/devices/virtual/misc/second_core/second_core_on;
		fi;
	fi;
	log -p i -t $FILE_NAME "*** CPU AUTOPLUG MODE: $cpu_mode ***: done";
}

CPU_GOVERNOR()
{
	local state="$1";
	local scaling_governor_tmp="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor";
	local tmp_governor=`cat $scaling_governor_tmp`;

	if [ "$cortexbrain_cpu" == on ]; then
		if [ "$state" == "awake" ]; then
			if [ "$tmp_governor" != $scaling_governor ]; then
				echo "$scaling_governor" > $scaling_governor_tmp;
			fi;
		elif [ "$state" == "sleep" ]; then
			if [ "$tmp_governor" != $scaling_governor_sleep ]; then
				echo "$scaling_governor_sleep" > $scaling_governor_tmp;
			fi;
		fi;

		local USED_GOV_NOW=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;

		log -p i -t $FILE_NAME "*** CPU_GOVERNOR: set $state GOV $USED_GOV_NOW ***: done";
	else
		log -p i -t $FILE_NAME "*** CPU_GOVERNOR: NO CHANGED ***: done";
	fi;
}

CALL_STATE()
{
	if [ "$DUMPSYS_STATE" -eq "1" ]; then

		# check the call state, not on call = 0, on call = 2
		local state_tmp=`echo "$TELE_DATA" | awk '/mCallState/ {print $1}'`;

		if [ "$state_tmp" != "mCallState=0" ]; then
			NOW_CALL_STATE=1;
		else
			NOW_CALL_STATE=0;
		fi;

		log -p i -t $FILE_NAME "*** CALL_STATE: $NOW_CALL_STATE ***";
	else
		NOW_CALL_STATE=0;
	fi;
}

# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	# Do not touch this
	CALL_STATE;
	MOUNT_SD_CARD;
	OVERRIDE_PROTECTION;

	# Check call state, if on call dont sleep
	if [ "$NOW_CALL_STATE" -eq "1" ]; then
		NOW_CALL_STATE=0;
	else
		# not on call, check if was powerd by USB on sleep, or didnt sleep at all
		if [ "$WAS_IN_SLEEP_MODE" -eq "1" ] && [ "$USB_POWER" -eq "0" ]; then
			CPU_AUTOPLUG "wake_boost";
			ENABLEMASK "awake";
			CPU_GOVERNOR "awake";
			LOGGER "awake";
			UKSMCTL "awake";
			MALI_TIMEOUT "wake_boost";
			KERNEL_TWEAKS "awake";
			NET "awake";
			MOBILE_DATA "awake";
			WIFI "awake";
			IO_SCHEDULER "awake";
			CPU_AUTOPLUG "awake";
			MALI_TIMEOUT "awake";
		else
			# Was powered by USB, and half sleep
			ENABLEMASK "awake";
			MALI_TIMEOUT "wake_boost";
			BATTERY_TWEAKS;
			CPU_AUTOPLUG "awake";
			MALI_TIMEOUT "awake";
			USB_POWER=0;

			log -p i -t $FILE_NAME "*** USB_POWER_WAKE: done ***";
		fi;
		#Didn't sleep, and was not powered by USB
	fi;
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	WAS_IN_SLEEP_MODE=0;

	# we only read the config when the screen turns off ...
	PROFILE=`cat $DATA_DIR/.active.profile`;
	. $DATA_DIR/${PROFILE}.profile;

	# we only read tele-data when the screen turns off ...
	if [ "$DUMPSYS_STATE" -eq "1" ]; then
		TELE_DATA=`dumpsys telephony.registry`;
	fi;

	# Check call state
	CALL_STATE;

	# Check Early Wakeup
	local TMP_EARLY_WAKEUP=`cat /tmp/early_wakeup`;

	# check if early_wakeup, or we on call
	if [ "$TMP_EARLY_WAKEUP" -eq "0" ] && [ "$NOW_CALL_STATE" -eq "0" ]; then
		WAS_IN_SLEEP_MODE=1;
		ENABLEMASK "sleep";
		CPU_AUTOPLUG "sleep";
		MALI_TIMEOUT "sleep";
		BATTERY_TWEAKS;
		CROND_SAFETY;
		OVERRIDE_PROTECTION;
		SWAPPINESS;

		# for devs use, if debug is on, then finish full sleep with usb connected
		if [ "$android_logger" == debug ]; then
			CHARGING=0;
		else
			CHARGING=`cat /sys/class/power_supply/battery/charging_source`;
		fi;

		# check if we powered by USB, if not sleep
		if [ "$CHARGING" -eq "0" ]; then
			CPU_GOVERNOR "sleep";
			IO_SCHEDULER "sleep";
			UKSMCTL "sleep";
			NET "sleep";
			WIFI "sleep";
			MOBILE_DATA "sleep";
			IPV6;
			KERNEL_TWEAKS "sleep";

			log -p i -t $FILE_NAME "*** SLEEP mode ***";

			LOGGER "sleep";
		else
			# Powered by USB
			USB_POWER=1;
			log -p i -t $FILE_NAME "*** SLEEP mode: USB CABLE CONNECTED! No real sleep mode! ***";
		fi;
	else
		# Check if on call
		if [ "$NOW_CALL_STATE" -eq "1" ]; then
			NOW_CALL_STATE=1;

			log -p i -t $FILE_NAME "*** on call: SLEEP aborted! ***";
		else
			# Early Wakeup detected
			log -p i -t $FILE_NAME "*** early wake up: SLEEP aborted! ***";
		fi;
	fi;

	# kill wait_for_fb_wake generated by /sbin/ext/wakecheck.sh
	pkill -f "cat /sys/power/wait_for_fb_wake"
}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;

if [ "$cortexbrain_background_process" -eq "1" ] && [ `pgrep -f "cat /sys/power/wait_for_fb_sleep" | wc -l` -eq "0" ] && [ `pgrep -f "cat /sys/power/wait_for_fb_wake" | wc -l` -eq "0" ]; then
	(while [ 1 ]; do
		# AWAKE State. all system ON
		cat /sys/power/wait_for_fb_wake > /dev/null 2>&1;
		AWAKE_MODE;
		sleep 2;

		# SLEEP state. All system to power save
		cat /sys/power/wait_for_fb_sleep > /dev/null 2>&1;
		sleep 2;
		/sbin/ext/wakecheck.sh;
		SLEEP_MODE;
	done &);
else
	if [ "$cortexbrain_background_process" -eq "0" ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;
