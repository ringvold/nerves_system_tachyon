# Next actions

Ordered by the phase gates in [project-brief.md](project-brief.md): do not
start a phase before the previous one boots on hardware.

## Done (2026-08-30)

- [x] GitHub repo `ringvold/nerves_system_tachyon` created, `origin` updated,
      `main` pushed
- [x] Manufacturing/provisioning data backed up
      (`~/tachyon-backups/2026-08-30/manufacturing_backup_*.zip` — copy it
      off-machine!) and EDL mode + flashing verified end-to-end
- [x] Stock updated: SysCon 1.0.20, then Ubuntu 24.04.4 beta (desktop, RoW)
      flashed — kernel `6.8.0-1058.59+particle1`, U-Boot+GRUB boot chain
- [x] Full partition recon on hardware (`~/tachyon-backups/tachyon-recon-*/`):
      24.04 keeps the gen-1 GPT; rootfs on old `system_a` (sda11), ESP on old
      `boot_b` (sdg25), U-Boot embedded in `xbl_a/b` via
      patchxbl.py+qtestsign (`tachyon-u-boot` install.sh)
- [x] fwup layout redesigned against the verified GPT: keep p1-p10, split
      `system_a` into p11 uboot_env / p12 boot / p13-14 rootfs_a/b / p15 data
- [x] SSH access as `particle@192.168.11.199` (key installed)

## Pre-hardware-flash (do now)

- [ ] Re-pin kernel: device runs `6.8.0-1058.59+particle1`; our
      `nerves_defconfig` pins tag `stable-6.8.0-1058.59particle3`. Check
      `particle-iot/tachyon-ubuntu-24.04-kernel` tags and align
- [x] First full system build PASSED (2026-08-30, Mac/Docker): env-SCSI
      U-Boot patch compiles, kernel builds from the harvested device config
      + fragment, artifact packaged. Fixes recorded in git history
      (xxd Docker image, device kernel config base, PCS_XPCS/certs/iris
      fragment disables). Desktop (distrobox) build also set up
      (GNU install + mise OTP 29)
- [x] Kernel VERIFIED ON HARDWARE (2026-08-31): our 6.8.12 Image boots the
      stock Ubuntu userspace via a GRUB test entry — Wi-Fi (ath11k), DRM and
      182 modules load. Lesson: initrd-less boot requires root=PARTUUID=/dev
      paths, never root=UUID= (kernel can't resolve fs UUIDs). Our kernel-tree
      DTB also verified (booted via GRUB devicetree command)
- [ ] Get the Particle debug adapter (10-pin serial console) — essential
      before any repartitioning/flash

## Phase 1 — Boot our things (reversible steps first)

- [ ] Build our U-Boot (env-SCSI patch, `CONFIG_ENV_SCSI_HW_PARTITION="0:11"`)
      and install via Particle's `tachyon-u-boot` `install.sh` flow
      (patchxbl.py + qtestsign → dd to xbl_a/xbl_b). Recovery: EDL restore
- [ ] Verify U-Boot serial console + `scsi scan` sees LUN 0 partitions;
      confirm U-Boot's scsi device numbering (assumed `scsi 0` = LUN 0/sda)
- [ ] Boot the Buildroot kernel manually from the U-Boot prompt before any
      fwup install
- [ ] Keep a battery attached (SysCon fake-battery bug still unfixed:
      `reboot` powers off)

## Phase 2 — Nerves on flash (gated on Phase 1 booting)

- [ ] Repartition LUN 0 with the sgdisk commands in README.md (delete p11
      system_a → create p11-p15). Stock Ubuntu becomes unbootable; EDL
      restores it
- [ ] Apply `fwup -t complete`, boot Nerves from rootfs_a, verify A/B
      upgrade + revert on hardware
- [ ] Verify `mix upload` / SSH via nerves_ssh works end-to-end

## Phase 3 — Peripherals (gated on Phase 2)

- [ ] Add a custom Buildroot package for WCN6750 ath11k firmware — harvest
      from stock `/lib/firmware/ath11k/WCN6750` (zstd-compressed); no
      Buildroot symbol exists. Bring up Wi-Fi via vintage_net
- [ ] 5G modem: NOTE — modem is RF-locked in the 24.04 beta and still leans
      on 20.04 components upstream. Re-evaluate vintage_net_qmi when Particle
      unlocks it (mind NA vs RoW firmware; this unit is RoW)
- [ ] Test GPIO/I2C/SPI on the 40-pin header with circuits_* (check TXS0108E
      level-shifter behavior)
