#!/bin/sh
# One-shot Phase 2 installer for the Particle Tachyon Nerves port.
#
# Run ONLY from the RAM-booted rescue shell (our Buildroot rootfs loaded as
# initramfs from the U-Boot prompt) — never from a system running off
# /dev/sda11. It carves the old system_a partition into the Nerves layout
# (p11-p15, see README.md) and applies the complete firmware with fwup.
# Stock Ubuntu on system_a becomes unbootable afterwards; the recovery path
# is EDL restore of the factory firmware.
set -e

echo "=== GPT before ==="
sgdisk --print /dev/sda

sgdisk --delete=11 /dev/sda
sgdisk --new=11:1198848:1199103  --typecode=11:8DA63339-0007-60C0-C436-083AC8230908 --change-name=11:uboot_env /dev/sda
sgdisk --new=12:1199104:1231871  --typecode=12:EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 --change-name=12:boot /dev/sda
sgdisk --new=13:1231872:1362943  --typecode=13:0FC63DAF-8483-4772-8E79-3D69D8477DE4 --change-name=13:rootfs_a /dev/sda
sgdisk --new=14:1362944:1494015  --typecode=14:0FC63DAF-8483-4772-8E79-3D69D8477DE4 --change-name=14:rootfs_b /dev/sda
sgdisk --new=15:1494016:30599162 --typecode=15:0FC63DAF-8483-4772-8E79-3D69D8477DE4 --change-name=15:data /dev/sda

echo "=== GPT after ==="
sgdisk --print /dev/sda

echo "=== fwup complete ==="
fwup -a -d /dev/sda -t complete -i /opt/tachyon.fw

# busybox in the rescue rootfs has no sync applet; flush via sysrq instead.
# fwup already fsync's the device, so this is belt-and-suspenders.
echo s > /proc/sysrq-trigger 2>/dev/null || true
echo "=== INSTALL-OK ==="
