# Nevada XT2613-1 KernelSU Next + SUSFS build notes

## Verified device baseline

- Device: Motorola Moto G (2026), XT2613-1
- Product / board: nevada
- Android device codename: utah
- Firmware baseline: W1WNS36.18-114-1
- SoC: MediaTek MT6835
- Boot image format: Android boot image header v4
- Kernel architecture: arm64, 4K pages
- Stock kernel release: 5.15.180-android13-8-00018-g9b2308ac0ad6-ab14563692
- ACK tag: android13-5.15-2025-05_r14
- ACK commit: 9b2308ac0ad616788fb57ba688aa07f0ff221355
- Android CI build: 14563692
- Compiler: Android clang 14.0.7, build 8508608, r450784e

## Proven stock equivalence

The kernel extracted from the verified Motorola boot.img is byte-for-byte identical to the Android GKI Image from CI build 14563692.

SHA-256:

```
58af5a627c5ade83fb0eca1cfc8da502fd2c07bcce162f3dfdd006a8102d27de
```

This means the boot kernel itself is stock Google GKI for this firmware. Device-specific Motorola / MediaTek support remains in the vendor side and modules.

## Verified stock boot-chain MD5 values

```
boot.img          c2ac324a92405786479cd0d2e022dbf6
init_boot.img     14f2fa22d3fd19b2e7bf250c03b05103
vendor_boot.img   a7f07c1504912437597a934d635be812
dtbo.img          5727c0656e8c3b82bfebb4ff6a16266c
vbmeta.img        23ff518b94fcc443758133c294e4a7cd
vbmeta_system.img ac268f75838469fb76bc6da2885c2dc3
```

AVB identity: `nevada_50`.

## Stock config facts

Recovered embedded IKCONFIG contained 6961 lines. Important values:

```
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_FTRACE=y
CONFIG_MODULES=y
CONFIG_MODVERSIONS=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_OVERLAY_FS=y
CONFIG_SECURITY_SELINUX=y
CONFIG_LTO=y
CONFIG_LTO_CLANG=y
CONFIG_LTO_CLANG_FULL=y
CONFIG_CFI_CLANG=y
CONFIG_SHADOW_CALL_STACK=y
CONFIG_TRIM_UNUSED_KSYMS=y
CONFIG_GKI_HACKS_TO_FIX=y
```

Recovered stock config SHA-256:

```
e3cdaf997a7e2eb70e441944bdfd9af359aa82e8a2d5cb9534d2bce5fcd4a78a
```

## KernelSU Next and SUSFS integration

Vanilla KernelSU Next v3.3.0 did not cleanly accept the upstream SUSFS KernelSU patch. The project therefore moved to the maintained SUSFS-aware KernelSU Next integration and the Android 13 / 5.15 SUSFS kernel patch.

On ACK r14, one SUSFS hunk in `fs/proc/task_mmu.c` required a small forward-port because r14 uses `get_pad_vma()` / `get_data_vma()` in `show_smap()` while the patch expected the older direct `vma = v` layout. The SUSFS inode-hide check was transplanted immediately before `memset(&mss, ...)`.

After integration:

```
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
```

## Build

Use:

```bash
./tools/build_nevada_ksun_susfs.sh
```

The build script:
1. verifies the exact ACK r14 commit,
2. fetches the matching Android clang r450784e toolchain,
3. removes only stale generated in-tree Kbuild artifacts,
4. runs an out-of-tree GKI defconfig build,
5. enables KernelSU Next and SUSFS,
6. produces Image and Image.gz.

Do not flash Image or Image.gz directly. The resulting kernel must be repacked into a Nevada boot-v4 image and validated before testing.

## Safety notes

Do not publish or redistribute Motorola proprietary firmware images. Publish scripts, hashes, source patches, documentation, and reproducible build instructions instead.

Do not use the Motorola full XML flashing sequence for kernel testing. It also contains destructive userdata / metadata operations and unrelated firmware partitions.

Keep an untouched verified W1WNS36.18-114-1 boot image for recovery.
