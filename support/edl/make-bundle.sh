#!/bin/sh
# Assemble a directory that `particle flash --tachyon <dir>` can flash: the
# Particle CLI's directory mode reads manifest.json, runs its bundled qdl
# with `--storage ufs --serial <SN> --include <base>` and the firehose +
# program XMLs listed there, in that order. This is the manifest-driven form
# tachyon-composer's FLASHING.md recommends over a hand-typed file list.
#
# The bundle only ever programs the Nerves sectors of LUN 0 (p11-p15). It
# carries no GPT images and no patch XML, so the device must already have
# the Nerves partition table (README.md sgdisk commands). LUN 1-6 — the
# Qualcomm boot chain, firmware set and modem NV — are never mentioned.
# Recovery path: `particle flash --tachyon <stock zip>` followed by
# `particle tachyon restore`.
#
# Usage: make-bundle.sh <images-dir> <prog_firehose_ddr.elf> <out-dir>
#   <images-dir> holds uboot-env.bin, Image, qcm6490-tachyon.dtb and
#   rootfs.squashfs. The firehose programmer is Qualcomm's and is not kept in
#   this repo; take it from any Tachyon OS package zip
#   (images/qcm6490/edl/prog_firehose_ddr.elf) or the CLI's assets/qdl/firehose.
set -eu

IMAGES=${1:?images dir}
FIREHOSE=${2:?prog_firehose_ddr.elf}
OUT=${3:?output dir}
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=edl

rm -rf "$OUT"
mkdir -p "$OUT/$BASE"
for f in uboot-env.bin Image qcm6490-tachyon.dtb rootfs.squashfs; do
    cp "$IMAGES/$f" "$OUT/$BASE/$f"
done
cp "$FIREHOSE" "$OUT/$BASE/prog_firehose_ddr.elf"

"$HERE/gen-rawprogram0.sh" "$OUT/$BASE" "$OUT/$BASE/rawprogram0-nerves.xml" >/dev/null

cat > "$OUT/manifest.json" <<EOF
{
  "release_name": "nerves_system_tachyon",
  "platform": "qcm6490",
  "os": "nerves",
  "targets": [
    {
      "qcm6490": {
        "edl": {
          "base": "$BASE",
          "firehose": "prog_firehose_ddr.elf",
          "program_xml": ["rawprogram0-nerves.xml"],
          "patch_xml": []
        }
      }
    }
  ]
}
EOF

echo "bundle ready: $OUT"
echo "  flash with:  particle flash --tachyon $OUT"
ls -la "$OUT/$BASE"
