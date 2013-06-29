#!/sbin/busybox sh

mount -t rootfs -o remount,rw rootfs

ln -s /sbin/busybox /sbin/sh

BB=/sbin/busybox

# protecting fuelgauge reset trigger.
chmod 000 /sys/devices/platform/i2c-gpio.9/i2c-9/9-0036/power_supply/fuelgauge/fg_reset_soc

mkdir -p /cache
chmod 777 /cache
mount -t ext4 /dev/block/mmcblk0p7 /cache
mkdir -p /cache/recovery
chmod 770 /cache/recovery
chown system.cache /cache/recovery

echo "50" > /sys/vibrator/pwm_val
