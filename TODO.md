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
- [x] Particle debug adapter received and verified (2026-09-04): both TTYs
      work at 115200 (`cu.usbserial-…0` = SysCon, `…1` = Linux/U-Boot
      console); full PBL→SBL→U-Boot→kernel boot log captured in
      `~/tachyon-backups/serial-logs/`. Secure Boot: Off confirmed in SBL log

## Phase 1 — Boot our things (reversible steps first)

- [x] U-Boot serial console verified: autoboot interrupt (1 s window) works;
      `scsi scan` numbering CONFIRMED — `scsi 0` = LUN 0 = /dev/sda
      (device 0 size 30599168×4096 matches), devices 1-6 = LUN 1-6.
      Stock env captured (618 bytes, `bootcmd=bootefi bootmgr`, env "in
      nowhere"). LESSON: U-Boot dev:part strings parse the partition number
      as HEX (`0:11` → "Invalid partition 17"); partition 11 is `0:b`.
      Fixed in uboot.env (`bootpart=0:c`) and nerves.fragment
      (`CONFIG_ENV_SCSI_HW_PARTITION="0:b"`)
- [x] Our Buildroot kernel booted MANUALLY from the U-Boot prompt
      (2026-09-04): `ext4load scsi 0:b` (kernel 41.5 MB in 50 ms) + our DTB,
      `booti` → Ubuntu userspace, no GRUB involved. U-Boot's FSG MAC fixup
      also runs in the booti path (ft_board_setup) — Wi-Fi MAC
      e8:8d:a6:6b:4e:51 verified in the booted system. Serial input needs
      char pacing (~20 ms/char, no flow control)
- [x] OUR U-BOOT INSTALLED AND RUNNING FROM XBL (2026-09-04): rebuilt with
      `0:b` + `CONFIG_BOOTDELAY=1`, installed via Particle's install.sh
      `--device` flow (qtestsign clone in /tmp/qtoolsign on device; xbl_a =
      /dev/sdc1, xbl_b = /dev/sdb1). Verified on serial: our banner
      (Jul 15 2026 build date), "Loading Environment from SCSI" → bad-CRC
      fallback to the built-in Particle default env (p11 is still ext4) →
      bootefi bootmgr → stock GRUB → stock Ubuntu boots normally. FSG MAC
      fixup and the 1 s autoboot window both work. Stock xbl_a/b backups:
      device ~/xbl_*-stock.backup + Mac ~/tachyon-backups/2026-09-04/
- [ ] Keep a battery attached (SysCon fake-battery bug still unfixed:
      `reboot` powers off)

Phase 1 gate PASSED: our U-Boot runs from flash, our kernel+DTB boot from
the U-Boot prompt. Phase 2 (repartitioning) is unlocked.

## Phase 2 — Nerves on flash (gated on Phase 1 booting)

- [x] Repartitioned LUN 0 on hardware (2026-09-04): RAM-booted our Buildroot
      rootfs as initramfs from the U-Boot prompt (`booti <kernel> <initrd> <dtb>`,
      `rdinit=/bin/sh`), ran support/phase2-install.sh (sgdisk delete p11 →
      create p11-p15, then `fwup -t complete`). GPT verified exactly as
      designed; fwup reported Success. Added BR2_PACKAGE_GPTFDISK for sgdisk
      on the target. Stock Ubuntu is now gone; EDL restore is recovery
- [x] Two boot-model bugs found & fixed (2026-09-04), NOT yet re-verified on
      hardware:
      1. fwup FAT is 512-byte-sector only; U-Boot refuses FAT whose sector
         size != device's 4096 ("FAT sector size mismatch (fs=512,dev=4096)").
         FIX: no filesystem on p12 — kernel+DTB are raw_write'n at fixed
         offsets (KERNEL_A/B, DTB_A/B in fwup-common.conf) and read with
         `scsi read` in uboot.env. LBAs there = fwup 512-byte offsets / 8.
      2. Particle's U-Boot defconfig drops `saveenv` ("Unknown command").
         FIX: CONFIG_CMD_SAVEENV=y in uboot/nerves.fragment — needs a U-Boot
         REBUILD + REINSTALL into XBL (patchxbl needs python3, not in the
         rescue rootfs — plan the reinstall path). Until then nerves_init's
         saveenv fails but is non-fatal (`;`-separated), so A/B boot state
         won't persist yet
- [x] AUTOMATIC BOOT CHAIN VERIFIED (2026-09-04 late): fixed in place from
      the U-Boot prompt — kernel/DTB `ext4load`ed from p10 and `scsi write`n
      raw to KERNEL_A/DTB_A, new uboot-env.bin sent with `loady` (ymodem via
      lrzsz `lsz --ymodem` on ONE bidirectional port FD, logger stopped
      first) and `scsi write`n to p11 LBA 0x124B00. From reset, with no
      manual input: env loads from SCSI → `scsi read` kernel + DTB →
      `Starting kernel` → squashfs root → erlinit. Stops only at
      "erlinit: Erlang installation not found" because the bare system
      image has no OTP/app — expected. Board parked at the U-Boot prompt.
      Gotchas: 0x124800 ≠ 1198848 (it is 0x124B00) — one env write landed
      in the tail of p10 (stock userdata; harmless for Nerves, but treat
      p10 as possibly damaged). SysCon brownout (vbat < 2046 mV floor)
      powered the board off during a pause — attach a battery
- [ ] Build a real firmware: minimal Nerves app (nerves_pack/nerves_ssh)
      with this system as a path dep → `mix firmware` → rootfs with OTP +
      release. Then get it onto the device — no network in Nerves yet, so
      either `loady` p13 at a high baud (921600+; ~130 MB), fastboot from
      U-Boot, or — preferred — EDL via Particle CLI's bundled qdl:
      `support/edl/gen-rawprogram0.sh <images> ` then
      `particle flash --tachyon prog_firehose_ddr.elf rawprogram0-nerves.xml`
      (LUN 0, Nerves sectors only; firehose elf ships in the CLI assets and
      every OS package zip). VERIFIED ON HARDWARE 2026-09-04: `particle
      flash --tachyon <bundle dir>` (support/edl/make-bundle.sh) flashed all
      six entries in 8.9 s (rootfs at 59 MB/s) with a single LUN0 XML and no
      patch files; the board then booted the identical Nerves chain. This is
      the initial-install path. Long term: Wi-Fi firmware → `mix upload`
      over SSH. Stock Ubuntu is not worth preserving — only avoid bricking
      (EDL is ROM+SysCon, unaffected by anything we write to LUN 0/XBL;
      factory restore = stock zip flash + `particle tachyon restore`)
- [ ] Rebuild + reinstall U-Boot with CONFIG_CMD_SAVEENV, then verify A/B
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
