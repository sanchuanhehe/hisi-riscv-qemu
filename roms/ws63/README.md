# WS63 (Hi3863) on-chip ROM dumps

Real mask-ROM / application-ROM contents read off a live HiSilicon WS63 dev board
on **2026-06-14** via the patched probe-rs fork (`hispark-rs/probe-rs`, branch
`add-hisilicon-ws63-bs21`) over J-Link/SWD — RISC-V DM @ `0x8000_0000` behind the
CoreSight DAP, hart-progbuf memory read.

These let the QEMU model run the genuine WS63 boot chain (mask ROM → loaderboot →
flashboot → app) instead of the empty-RAM `ws63.bootrom` stub that currently skips
the vendor bootloader (see `src/hw/riscv/ws63.c`, `WS63_BOOTROM_BASE`).

## Files

| File | Load address | Size | Region |
|------|--------------|------|--------|
| `ws63_rom_0x100000-0x14c000.bin` | `0x0010_0000` | 311296 B (0x4C000, 304 KiB) | **Full ROM** (bootrom + app-rom, authoritative) |
| `ws63_bootrom_0x100000.bin`      | `0x0010_0000` | 36864 B (0x9000, 36 KiB)    | Boot ROM (mask ROM) only |
| `ws63_approm_0x109000.bin`       | `0x0010_9000` | 274432 B (0x43000, 268 KiB) | Application ROM only |

The two split files are exact slices of the full dump (`bootrom` = bytes
`0x0..0x9000`, `approm` = bytes `0x9000..0x4C000`).

### SHA-256

```text
ws63_rom_0x100000-0x14c000.bin  22d92fbba1a7a7333a6fc4a8e1f38b791c06ec3b495e5dc8734bfb44575f39db
ws63_bootrom_0x100000.bin       0f317521327369952046ffa04df2005c9c7d560ebec845dab9b8b345346daf93
ws63_approm_0x109000.bin        c9a105a2bf1d0c1fbaab3d24eb7ae4adf28fc38150d568a9ed610af04e75e4db
```

## Notes

- ROM base `0x100000` is also the **reset vector**: word 0 = `0x0240006f` = `j 0x100024`.
- This is read-only ROM content; it is chip/silicon-revision specific to the dumped
  board. Treat as a captured artifact, not a redistributable vendor binary — keep
  internal to this project.
- To use in QEMU, load the blob into the `0x100000` region instead of zero-filling it
  (e.g. `rom_add_blob_fixed` / `load_image_targphys` at `WS63_BOOTROM_BASE`), and let
  the core boot from the reset vector rather than `-kernel`-jumping into the app.

## How it was dumped

```sh
probe-rs read --chip WS63 --chip-description-path HiSilicon_WS63.yaml \
    -f binary -o ws63_rom_0x100000-0x14c000.bin b32 0x100000 77824
```
(77824 words × 4 B = 0x4C000 B; ~3 min over SWD.)
