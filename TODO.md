# Next actions

Ordered by the phase gates in [project-brief.md](project-brief.md): do not
start a phase before the previous one boots on hardware. Mirrors the
"Nerves Tachyon — Next Actions" list in Superlist.

## Pre-hardware (do now)

- [ ] Create the GitHub repo `ringvold/nerves_system_tachyon`, point `origin`
      at it, and push `main`
- [ ] Run the first full system build (`mix deps.get && MIX_TARGET=tachyon
      mix firmware` from a test app, or `mix nerves.system.shell`) to shake
      out the U-Boot env-SCSI patch compile, the `qcm6490_tachyon` defconfig
      `#include` handling, and the kernel fragment
- [ ] Get the Particle debug adapter (10-pin serial console) — essential for
      everything after this

## Phase 0 — Recon on stock Ubuntu (no flashing)

- [ ] Dump all partition tables (`sgdisk -p /dev/sd[a-g]`, `lsblk`) and
      verify the assumed LUN 0 offsets (efi at 4K-LBA 6, persist at 131078).
      Fix `fwup_include/fwup-common.conf`, `rootfs_overlay/etc/fw_env.config`
      and the README sgdisk numbers if they differ
- [ ] Back up manufacturing/provisioning data per Particle's "Restoring Back
      to Factory Firmware" docs
- [ ] Verify EDL mode works end-to-end (power button 3 s → yellow LED →
      Particle CLI factory restore)
- [ ] Copy `/usr/bin/particle-tachyon-syscon.sh` and
      `collect-particle-logs.sh` into the repo for reference; record
      `tachyon version` output (syscon/uboot/kernel versions)
- [ ] Confirm serial console works via the debug adapter (ttyMSM0, 115200)
- [ ] Keep a battery attached during all work (SysCon fake-battery mode
      turns `reboot` into power-off)

## Phase 1 — Boot our kernel (nothing written permanently)

- [ ] Decide and document the uefi_a flashing story for U-Boot (qtestsign
      test-signing + fastboot vs EDL) and flash our U-Boot build
- [ ] Boot the Buildroot kernel manually from the U-Boot prompt (load over
      fastboot/USB or from a spare region) before any fwup install
- [ ] Iterate `linux/nerves.fragment` against Particle's shipping Ubuntu
      config until the kernel reaches a console on ttyMSM0

## Phase 2 — Nerves on flash (gated on Phase 1 booting)

- [ ] Repartition LUN 0 with the sgdisk commands from the README
- [ ] Apply `fwup -t complete`, boot Nerves from rootfs_a, verify A/B
      upgrade + revert on hardware
- [ ] Verify `mix upload` / SSH via nerves_ssh works end-to-end

## Phase 3 — Peripherals (gated on Phase 2)

- [ ] Add a custom Buildroot package for WCN6750 ath11k firmware (no
      Buildroot symbol exists) and bring up Wi-Fi via vintage_net
- [ ] Evaluate vintage_net_qmi for the Quectel 5G modem (mind NA vs RoW
      firmware)
- [ ] Test GPIO/I2C/SPI on the 40-pin header with circuits_* (check TXS0108E
      level-shifter behavior)
