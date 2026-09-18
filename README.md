# Nevada Root / Kernel Workspace

Development workspace for the Motorola Moto G (2026) XT2613-1 (nevada/utah), based on the known-good W1WNS36.18-114-1 boot chain in this repository.

## Baseline
- Device: XT2613-1
- Platform: MT6835
- Android: 16
- Stock firmware baseline: W1WNS36.18-114-1
- Kernel lineage: 5.15 / android13
- Root target: KernelSU Next
- SUSFS target: matching 5.15 branch

The original boot-chain images remain untouched at repository root.

## First stage

Run:

```bash
chmod +x tools/inspect_stock.sh
./tools/inspect_stock.sh
```

This verifies the stock files, records cryptographic hashes, identifies Android boot/vendor boot metadata when host tools are available, and writes results under `out/stock-analysis/`.

Nothing in the inspection script flashes the phone.

## Roadmap

1. Fingerprint known-good stock boot chain.
2. Extract kernel/build metadata and establish reproducible image unpack/repack.
3. Match Motorola MTK 5.15 source/config.
4. Integrate KernelSU Next.
5. Integrate matching SUSFS.
6. Build and validate a test boot image.
7. Add recovery/device/vendor bring-up for the custom ROM.
