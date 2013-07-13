#!/sbin/busybox sh

(
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/${PROFILE}.profile;

	if [ "$cron_fix_permissions" == "on" ]; then
		while [ ! `cat /proc/loadavg | cut -c1-4` \< "3.50" ]; do
			echo "Waiting For CPU to cool down";
			sleep 30;
		done;

		/sbin/fix_permissions -l -r -v > /dev/null 2>&1;
		date +%H:%M-%D-%Z > /data/crontab/cron-fix_permissions;
		echo "Done! Fixed Apps Permissions" >> /data/crontab/cron-fix_permissions;
		echo "---------------------------------" >> /data/nx_cron.log;
		date >> /data/nx_cron.log;
		echo "Fix Perm Cron Job Executed" >> /data/nx_cron.log;
		echo "---------------------------------" >> /data/nx_cron.log;
	fi;
)&

