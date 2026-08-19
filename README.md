# Nerves System for the Particle Tachyon

This is the base Nerves System configuration for the
[Particle Tachyon](https://www.particle.io/tachyon/) single-board computer
(Qualcomm Dragonwing QCM6490).

**Status: pre-alpha, does not boot on hardware yet.** See
[project-brief.md](project-brief.md) for the plan and current phase.

| Feature        | Description                                            |
| -------------- | ------------------------------------------------------ |
| CPU            | Qualcomm QCM6490 (8× Kryo 670, aarch64)                |
| Memory         | 4–8 GB DRAM                                            |
| Storage        | 64–128 GB UFS                                          |
| Linux kernel   | Particle's Qualcomm-based kernel fork                  |
| IEx terminal   | Serial console via the 10-pin debug connector          |
| GPIO, I2C, SPI | Yes - [Elixir Circuits](https://github.com/elixir-circuits) (40-pin header) |
| WiFi           | Wi-Fi 6E (ath11k / WCN6750) — planned                  |
| 5G modem       | Quectel baseband via QMI — planned                     |
| Ethernet       | No built-in Ethernet (USB adapters possible)           |
| HW watchdog    | Planned                                                |

## Architecture

The Tachyon boots through Qualcomm's proprietary boot chain into open-source
U-Boot, which then boots Linux:

```
BootROM → XBL/ABL (Qualcomm, untouched) → U-Boot (Particle fork) → Linux
```

Because real U-Boot runs on this board, the Nerves A/B firmware update model
follows the `nerves_system_bbb` pattern rather than the Raspberry Pi one:

* fwup writes A/B root filesystem partitions on UFS
* The U-Boot environment selects the active slot; `nerves_runtime` /
  `uboot_env` toggle it from Elixir
* U-Boot's boot logic (`uboot/uboot.env`) reverts to the previous slot if new
  firmware never validates itself

Qualcomm-owned partitions (XBL, ABL, modem, fsg, …) are never written by this
system. Only the U-Boot environment, boot, and Nerves-created rootfs/app
partitions are touched.

## Safety / recovery

Before flashing anything to a Tachyon:

1. Back up manufacturing/provisioning data per Particle's "Restoring Back to
   Factory Firmware" docs. A restored device won't function without it.
2. Verify EDL mode works (unplug power, reconnect USB-C + battery, hold the
   power button ~3 s until the LED flashes yellow). The Particle CLI can
   reflash factory firmware from `linux-dist.particle.io` — this is the
   recovery path for every flash operation.

Known SysCon quirk: with no battery attached ("fake battery mode"), `reboot`
powers the board off instead of rebooting. Keep a battery attached during
development or expect to press the power button after reboots.

## Storage layout (UFS LUN 0)

The Tachyon's UFS uses **4096-byte logical sectors**. Stock LUN 0 is
`efi` (512 MiB ESP) + `persist` (30 MiB) + `system` (10 GiB+, Ubuntu rootfs).
Nerves keeps `efi` and `persist` in place and carves `system`'s space into:

| # | Name      | Start (4K sector) | Size    | Contents                          |
|---|-----------|-------------------|---------|-----------------------------------|
| 1 | BOOT      | 6 (stock)         | 512 MiB | FAT32: `Image.a/b`, `tachyon-a/b.dtb` (stock `efi` partition) |
| 2 | persist   | (stock)           | 30 MiB  | Stock calibration data — never written |
| 3 | uboot_env | 139264            | 1 MiB   | Raw U-Boot env (128 KiB) at byte 0x22000000 |
| 4 | rootfs_a  | 139520            | 512 MiB | squashfs                          |
| 5 | rootfs_b  | 270592            | 512 MiB | squashfs                          |
| 6 | data      | 401664            | rest    | f2fs application data             |

All other LUNs (XBL, firmware, modem NV) are untouched. fwup never writes a
partition table on this platform — the GPT is modified once at provisioning
time:

```sh
# On stock Ubuntu (AFTER the manufacturing-data backup and EDL check!).
# Verify first that the stock layout matches: sgdisk -p /dev/sda
sgdisk --delete=3 /dev/sda
sgdisk --new=3:139264:139519  --typecode=3:8DA63339-0007-60C0-C436-083AC8230908 --change-name=3:uboot_env /dev/sda
sgdisk --new=4:139520:270591  --typecode=4:0FC63DAF-8483-4772-8E79-3D69D8477DE4 --change-name=4:rootfs_a /dev/sda
sgdisk --new=5:270592:401663  --typecode=5:0FC63DAF-8483-4772-8E79-3D69D8477DE4 --change-name=5:rootfs_b /dev/sda
sgdisk --new=6:401664:0       --typecode=6:0FC63DAF-8483-4772-8E79-3D69D8477DE4 --change-name=6:data /dev/sda
```

U-Boot (built by this system with the env-SCSI patch, see `uboot/`) is
flashed to the `uefi_a` partition on LUN 4 once during provisioning. The
initial Nerves firmware (`fwup -t complete`) is then applied via
fastboot/EDL — the exact initial-install flow is still being worked out on
hardware (Phase 2); `mix upload` handles everything after that.

## Using the system

To build firmware for the Tachyon:

```sh
export MIX_TARGET=tachyon
mix deps.get
mix firmware
```

This system is not published to hex.pm; reference it from your project as a
git/path dependency:

```elixir
{:nerves_system_tachyon, github: "ringvold/nerves_system_tachyon", runtime: false, targets: :tachyon}
```

## Console access

The IEx console is on the Linux serial console UART, exposed on the 10-pin
(2×5) debug connector. Particle's debug adapter breaks this out together with
the SysCon UART. Serial settings: 115200 8N1.

## Provenance

This repository started as a clone of
[`nerves_system_rpi5`](https://github.com/nerves-project/nerves_system_rpi5)
(toolchain and Buildroot skeleton) with boot logic modeled on
[`nerves_system_bbb`](https://github.com/nerves-project/nerves_system_bbb)
(real U-Boot A/B slot selection).
