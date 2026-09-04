# EDL initial install

How to put a Nerves firmware on a Tachyon that has no working OS, using the
Qualcomm EDL (Emergency Download) path that Particle's own tooling uses.

## How `particle flash --tachyon` works

The Particle CLI wraps Particle's fork of linux-msm `qdl`. In EDL mode the
board enumerates as USB `05c6:9008`; `qdl` uploads Qualcomm's programmer
`prog_firehose_ddr.elf` over Sahara, then feeds it firehose XML:
`rawprogram*.xml` (`<program>`/`<erase>` addressed by LUN
`physical_partition_number`, `start_sector` and `num_partition_sectors`,
4096-byte sectors) followed by `patch*.xml` (GPT header/CRC fix-ups). Firehose
does not know about GPT at all — it writes where it is told.

The CLI always passes `--storage ufs --serial <SN>` itself. Given a directory
it reads `manifest.json` → `targets[0].qcm6490.edl.{base, firehose,
program_xml[], patch_xml[]}`, runs qdl from that directory with
`--include <base>`, and programs firehose, then every program XML, then every
patch XML, in that order.

## What the Nerves bundle does

`make-bundle.sh` builds such a directory from a firmware's images:

| label | LUN 0 sector | content |
| --- | --- | --- |
| uboot_env | 1198848 (p11) | uboot-env.bin |
| kernel_a | 1199104 (p12, slot A) | Image, raw |
| dtb_a | 1214464 (p12, slot A) | qcm6490-tachyon.dtb, raw |
| rootfs_a | 1231872 (p13) | rootfs.squashfs |
| rootfs_b / data | 1362944 / 1494016 | 128 KiB of 0xff (invalidate, as fwup does) |

Sectors are the fwup 512-byte offsets in `fwup_include/fwup-common.conf`
divided by 8. Nothing outside p11-p15 is written: no GPT, no patch XML, and
LUN 1-6 (Qualcomm boot chain, the firmware set on LUN 6, modem NV on LUN 5)
are never mentioned. tachyon-composer's warning that "LUN 6 cannot be
skipped" is about blank boards — it holds everything XBL hands off to. A
Tachyon that already boots keeps it.

Consequently the device must already carry the Nerves GPT (README.md sgdisk
commands, or `support/phase2-install.sh` from a RAM-booted rescue shell).
Writing the partition table itself through EDL is a possible later addition
(PrimaryGPT/BackupGPT program entries + patch0.xml, see the stock bundle).

## Steps

1. Get `prog_firehose_ddr.elf`: `unzip -j <tachyon OS zip>
   '*/edl/prog_firehose_ddr.elf'` (also in the CLI source under
   `assets/qdl/firehose/`). It is Qualcomm's signed programmer and is not
   committed here.
2. Collect the firmware images (a system artifact's `images/` dir, or the
   resources of a `mix firmware` .fw: `fwup -i fw.fw -m` lists them,
   `unzip` extracts `data/*`).
3. `support/edl/make-bundle.sh <images> prog_firehose_ddr.elf <out-dir>`
4. Put the Tachyon in EDL: unplug all power, reconnect USB-C (data to the
   host) and battery, hold the power button ~3 s until the LED blinks yellow.
   `particle tachyon identify` confirms it.
5. `particle flash --tachyon <out-dir>` — logs land in
   `~/.particle/logs/tachyon_flash_*.log`.
6. The board resets and boots Nerves through our U-Boot.

Recovery, as always: `particle flash --tachyon <stock zip>` then
`particle tachyon restore` with the manufacturing backup.

Related tool: `particle-iot/tachyon-tools` (`bundle_partition_filter.py
list|validate|filter-in|filter-out`) lists and trims stock bundles without
unpacking them — handy for diffing the official layout between releases. Its
filters keep every patch XML, so it is not a way to build a LUN0-only bundle.
