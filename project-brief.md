
# nerves_system_tachyon — Project Brief

Goal: Build a custom Nerves system for the Particle Tachyon SBC (Qualcomm QCM6490), so Elixir/Nerves firmware can run as the primary OS on the application processor, with Nerves' immutable A/B firmware updates via fwup.

## Hardware summary

- SoC: Qualcomm Dragonwing QCM6490 (8× Kryo 670, aarch64), Adreno 643 GPU, Hexagon 770 DSP
- RAM/Storage: 4–8 GB RAM, 64–128 GB **UFS** (not eMMC/SD — OS lives on internal flash)
- Connectivity: 5G modem (Quectel baseband, region-specific NA/RoW builds), Wi-Fi 6E, BT 5.2
- Form factor: Raspberry Pi 40-pin HAT layout, USB-C (PD + DisplayPort alt mode)
- SysCon: separate microcontroller managing power sequencing, charging, boot button, LED. **Closed source** firmware, communicates with the AP over UART. Config via `/usr/bin/particle-tachyon-syscon.sh` on stock Ubuntu — study this script to learn the UART protocol.
- Debug: 10-pin (2×5) debug connector exposes SysCon UART + Linux serial console. Get the Particle debug adapter — serial console access is essential for this project.

## Boot chain

```
Qualcomm BootROM → XBL/ABL (Qualcomm, proprietary, DO NOT TOUCH)
  → U-Boot (open source, Particle fork, locally buildable with custom DTS)
    → Linux kernel (source available from Particle)
```

Key insight: because Tachyon already uses U-Boot, the Nerves A/B model maps cleanly:
- fwup writes A/B rootfs partitions on UFS
- U-Boot env selects active slot; `nerves_runtime` + `uboot_env` toggle it
- This is the same pattern as nerves_system_rpi*, just on UFS instead of SD/eMMC

## What the closed SysCon means (and doesn't)

- SysCon runs independently of the AP OS — Nerves replacing Ubuntu does not affect power sequencing, charging, or the boot button.
- Known bug (unfixable without SysCon source): in "fake battery mode" (no battery attached), `reboot` powers the board off instead of rebooting to U-Boot. Plan around this during development: keep the battery attached, or expect to press the power button after reboots.
- Do not attempt to modify SysCon firmware — Particle warns this can permanently damage the board.

## Recovery / anti-brick

Before flashing ANYTHING:
1. Back up manufacturing/provisioning data (see Particle docs "Restoring Back to Factory Firmware"). Without it, a restored device won't function.
2. Verify EDL mode works: unplug all power, reconnect USB-C + battery, hold power button 3 s → LED flashes yellow → Particle CLI can reflash factory firmware from `linux-dist.particle.io`.
3. Never write to Qualcomm partitions (XBL, ABL, modem, fsg, etc.). Only touch U-Boot env, boot, and rootfs partitions we create/replace.

## Plan of attack

### Phase 0 — Recon (no flashing)
- Boot stock Ubuntu; dump full partition table (`sgdisk -p` / `lsblk`), note which partitions hold u-boot, kernel, rootfs, and which are Qualcomm-owned.
- Copy `/usr/bin/particle-tachyon-syscon.sh` and `collect-particle-logs.sh` for reference.
- `tachyon version` → record syscon_firmware, uboot, kernel versions.
- Clone and study:
  - `particle-iot/tachyon-composer` (image assembly, versions.json, how uboot/kernel/overlays combine)
  - Particle's U-Boot fork (find via composer's INPUT_UBOOT_DIR docs; community thread "Community Help - Uboot fork" is relevant)
  - Particle's kernel repo + defconfig + DTS files
- Get serial console working via debug adapter.

### Phase 1 — Buildroot boots (no Nerves yet)
- Minimal Buildroot defconfig: Particle kernel source + their defconfig, aarch64 glibc toolchain, read-only squashfs rootfs, serial console getty.
- Reuse Particle's DTS unchanged.
- Package required firmware blobs (Wi-Fi ath11k, GPU/DSP optional at this stage) via Buildroot BR2_PACKAGE_LINUX_FIRMWARE or custom packages pulled from the stock image.
- Boot it manually from U-Boot over serial (tftp or load from a spare partition) before writing anything permanent.
- Prior art to lean on: the Fairphone 2 (Snapdragon 801) Nerves port write-up on Elixir Forum ("Running Nerves on Android e-waste") — same methodology: Buildroot first, PostmarketOS-style kernel config reuse, then Nerves.

### Phase 2 — Nerves-ify

**Starting point (decided): this repo is a clone of `nerves_system_rpi5`, renamed to `nerves_system_tachyon`** per the "Customizing Your Nerves System" docs. rpi5 provides the aarch64 glibc toolchain, modern Buildroot setup, and overall system skeleton (mix.exs nerves_package config, nerves_defconfig, post-build.sh, rootfs_overlay, artifact CI).

**Important: do NOT copy the rpi5 boot flow.** Raspberry Pi systems don't run real U-Boot — they only use the uboot-env *format* as a KV store for the Broadcom bootloader. Tachyon runs actual U-Boot, so the boot/A-B logic must instead follow the pattern from **`nerves_system_bbb`** (or `nerves_system_osd32mp1`): real U-Boot boot script + env-based A/B slot selection with revert-on-failed-boot. Those systems are armv7, but only the toolchain differs — the U-Boot boot logic is architecture-independent. Use BBB's `fwup.conf` and uboot script as the template for that portion.

Concrete steps:
- Rename rpi5 clone → `nerves_system_tachyon` (module names, @app, artifact_sites) per docs.
- Swap kernel in `nerves_defconfig` to Particle's kernel source + defconfig + DTS.
- Replace the boot portion of `fwup.conf`: UFS partition layout, U-Boot env partition/offset, A/B rootfs + app data partitions carved from the stock rootfs space. Keep all Qualcomm partitions intact. Model the A/B-via-U-Boot-env mechanics on BBB's fwup.conf.
- Add required firmware blobs as custom Buildroot packages.
- Configure `uboot_env` / `nerves_runtime` against the real env location so slot toggling and validation work.
- erlinit, nerves_runtime, nerves_pack; ssh access via `nerves_ssh`.
- Decide flashing story: fastboot (SysCon supports it via FastBootEnabled, hold button 8 s) or EDL-based scripting for initial install; `mix upload` thereafter.

### Phase 3 — Peripherals
- Wi-Fi via vintage_net (ath11k)
- 5G modem: QMI over the Quectel baseband — evaluate `nerves-networking/qmi` + vintage_net_qmi; note region-specific modem firmware (NA vs RoW)
- GPIO/I2C/SPI on the 40-pin header via circuits_* (check TXS0108E level shifter behavior)
- Optional/later: GPU, Hexagon DSP/AI accelerator (likely needs significant blob + userspace work — deprioritize)

## Known risks

- UFS + Qualcomm boot chain is less traveled in Nerves land than eMMC/SD — expect fwup/partitioning surprises.
- Blob licensing: firmware blobs extracted from stock image are fine for personal use; redistribution of the built system may be restricted.
- SysCon reboot bug in fake battery mode (see above).
- Particle may still change partition layout between releases — pin against a specific stock release version.

## References

- Particle developer docs: https://developer.particle.io/tachyon/ (software overview, syscon, power, ubuntu-24.04-build, restore)
- https://github.com/particle-iot/tachyon-composer
- Nerves custom systems: https://hexdocs.pm/nerves/customizing-systems.html
- https://github.com/nerves-project/nerves_system_br
- https://github.com/nerves-project/nerves_system_rpi5 (base skeleton this repo is cloned from — aarch64 toolchain, Buildroot setup)
- https://github.com/nerves-project/nerves_system_bbb (template for real U-Boot boot script + env-based A/B — RPi systems don't run real U-Boot)
- Fairphone 2 Nerves port: https://elixirforum.com/t/running-nerves-on-android-e-waste/70187
- QMI in Elixir: https://github.com/nerves-networking/qmi
- Community threads: "Linux kernel source for Tachyon", "Community Help - Uboot fork", "Request for open source the SysCon Microcontroller firmware"

## Working conventions for Claude Code

- Never suggest writing to Qualcomm-owned partitions or modifying SysCon firmware.
- All flashing steps must be reversible via EDL restore; state the recovery path when proposing a flash operation.
- Prefer studying Particle's existing repos over reinventing; pin versions explicitly.
- This repo started as an rpi5 clone: reuse its toolchain/Buildroot structure, but never carry over rpi5 boot/firmware assumptions (config.txt, Broadcom bootloader, fake-uboot-env-as-KV-store). All boot logic follows the BBB real-U-Boot pattern.
- Phase gates: do not start Phase N+1 work until Phase N boots on hardware.
