# U-Boot for the Particle Tachyon

U-Boot is built from Particle's fork:

* Repo: https://github.com/particle-iot/tachyon-u-boot
* Branch: `tachyon` (U-Boot 2025.04 base), pinned by commit in
  `../nerves_defconfig`
* Defconfig: `qcm6490_tachyon_defconfig` (targets the "Linux Embedded"
  partition layout where U-Boot lives in the `uefi_a`/`uefi_b` partitions on
  LUN 4)

## Files here

* `0001-env-Add-support-for-SCSI-devices.patch` — backport of upstream
  U-Boot's `env/scsi.c` driver. Stock Particle U-Boot has no persistent
  environment (compiled-in `default.env`, `bootcmd=bootefi bootmgr` → GRUB).
  Nerves needs U-Boot, fwup, and Elixir to share one raw environment block
  for A/B slot selection, so this patch lets U-Boot load/save the env at the
  start of the `uboot_env` GPT partition on UFS. The upstream partition-UUID
  lookup path is dropped (helper doesn't exist in 2025.04); the partition is
  selected by `CONFIG_ENV_SCSI_HW_PARTITION="0:3"`.
* `nerves.fragment` — Kconfig fragment enabling the SCSI env location and
  the Nerves boot behavior.
* `uboot.env` — the full Nerves environment (A/B boot + revert logic).
  Compiled to `images/uboot-env.bin` with mkenvimage and written by fwup.
  The compiled-in Particle default env is intentionally left unchanged as a
  fallback: with a blank/corrupt env partition the board still runs
  `bootefi bootmgr` (stock GRUB flow, if present).

## Flashing U-Boot

The U-Boot binary itself is NOT part of the fwup firmware update. It is
flashed once to the `uefi_a` partition (LUN 4) during provisioning — via
fastboot or EDL — after test-signing. See the top-level README. Never write
any other LUN 4 partition; recovery is always possible via EDL
(`particle` CLI, factory firmware from linux-dist.particle.io) as long as the
Qualcomm partitions are intact.
