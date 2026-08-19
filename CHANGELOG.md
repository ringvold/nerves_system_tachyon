# Changelog

## v0.1.0

Initial development version. Forked from `nerves_system_rpi5` v2.1.1 and
re-targeted at the Particle Tachyon (Qualcomm QCM6490):

* aarch64 glibc toolchain and Buildroot skeleton retained from rpi5
* Boot/A-B update logic rebuilt on the real-U-Boot pattern from
  `nerves_system_bbb` (boot script + U-Boot environment slot selection with
  revert-on-failed-boot)
* Raspberry Pi boot firmware, config.txt/cmdline.txt, and Broadcom-specific
  packages removed
