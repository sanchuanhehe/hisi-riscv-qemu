#!/usr/bin/env bash
# Build a BS21/BS2X flash1 image from the fbb_bs2x `bs21e_all.fwpkg` firmware
# package, laying each component out at its partition flash offset.
#
# The fwpkg is a simple archive: a 12-byte header (magic 0xefbeaddf) then 0x34-byte
# entries { name[0x20], fwpkg_off[4], size[4], ... } for loaderboot/partition/
# flashboot_a/b/application/nv. The flash offsets come from the partition table
# (partition.bin, magic 0x4b87a52d): read as {flash_addr, size} pairs they are
# loaderboot@0x1000, flashboot_a@0xb000, application@0x15000, flashboot_b@0x9d000,
# nv@0xfe000 (partition table itself @0x0).
#
# The result loads at flash1 XIP base 0x90100000. NB the QEMU generic `-device
# loader` caps a single raw load at ~0x10000, so bs21-vendor-boot.sh chunk-loads it.
#
# Usage: bs21-build-flash.sh <bs21e_all.fwpkg> <out flash1.bin>
set -euo pipefail
FWPKG="${1:?usage: bs21-build-flash.sh <bs21e_all.fwpkg> <out.bin>}"
OUT="${2:?output path}"

python3 - "$FWPKG" "$OUT" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
assert struct.unpack_from('<I', d, 0)[0] == 0xefbeaddf, "not a fwpkg"
comp, off = {}, 0xc
while off + 0x34 <= len(d):
    name = d[off:off + 0x20].split(b'\0')[0].decode('ascii', 'replace')
    if '.bin' not in name:
        break
    foff, size = struct.unpack_from('<II', d, off + 0x20)
    comp[name] = d[foff:foff + size]
    off += 0x34
# flash offsets from the partition table {flash_addr,size} pairs
layout = {
    'partition.bin':        0x00000,
    'loaderboot_sign.bin':  0x01000,
    'flashboot_sign_a.bin': 0x0b000,
    'application_sign.bin': 0x15000,
    'flashboot_sign_b.bin': 0x9d000,
    'bs21e_all_nv.bin':     0xfe000,
}
end = max(o + len(comp[n]) for n, o in layout.items())
flash = bytearray(b'\xff' * end)
for n, o in layout.items():
    flash[o:o + len(comp[n])] = comp[n]
    print(f"  {n:24} @flash 0x{o:06x} (XIP 0x{0x90100000 + o:08x}) size 0x{len(comp[n]):x}")
open(sys.argv[2], 'wb').write(flash)
print(f"flash1 image: 0x{len(flash):x} bytes -> {sys.argv[2]} (load at 0x90100000)")
PY
