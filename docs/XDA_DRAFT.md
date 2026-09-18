# XDA post draft: Moto G 2026 XT2613-1 (nevada) KernelSU Next + SUSFS

> Draft. Publish only after the first boot-tested image is confirmed.

## [KERNEL][XT2613-1][nevada][Android 16] KernelSU Next + SUSFS for Moto G 2026

This project documents a reproducible KernelSU Next + SUSFS kernel build for the Motorola Moto G (2026) XT2613-1, product `nevada`, Android codename `utah`.

### Tested firmware baseline

`W1WNS36.18-114-1`

The Motorola stock boot chain was verified against the firmware manifest before any kernel work.

### Stock kernel discovery

The stock boot image contains:

```
5.15.180-android13-8-00018-g9b2308ac0ad6-ab14563692
```

The embedded kernel configuration was recovered with IKCONFIG and the toolchain was identified as Android clang 14.0.7 / r450784e.

The important discovery was that the decompressed kernel from Motorola's stock boot.img is byte-for-byte identical to Google's GKI Image from Android CI build 14563692:

```
ACK tag: android13-5.15-2025-05_r14
commit: 9b2308ac0ad616788fb57ba688aa07f0ff221355
SHA-256: 58af5a627c5ade83fb0eca1cfc8da502fd2c07bcce162f3dfdd006a8102d27de
```

That gave us an exact, reproducible kernel baseline instead of relying on an approximate Motorola source branch.

### KernelSU Next + SUSFS

The build uses the exact ACK baseline above, KernelSU Next with SUSFS support, and the SUSFS Android13-5.15 kernel patch.

One `fs/proc/task_mmu.c` hunk required a forward-port for the newer padded-VMA layout used by the r14 tree. The resulting configuration contains:

```
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
```

### What will be published

- reproducible build scripts
- exact source / toolchain pins
- hashes for stock verification
- Nevada-specific SUSFS forward-port
- boot image repack tooling
- installation and recovery instructions
- source code required by the applicable licenses

Motorola proprietary firmware files will not be redistributed.

### Warning

This targets XT2613-1 / nevada and the documented firmware baseline. Do not flash it to other Motorola models simply because they use MT6835.

Keep your known-good stock boot image and a working fastboot recovery path.

### Credits

Android Common Kernel / AOSP, KernelSU Next, SUSFS, and the open-source Android kernel community.

---

The first public release should be posted only after the generated boot image has been boot-tested and recovery has been verified.
