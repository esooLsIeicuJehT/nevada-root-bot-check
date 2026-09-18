#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${PUBLIC_REPO_NAME:-moto-g-2026-nevada-ksun-susfs}"
DEST="${1:-$ROOT/../$NAME}"

rm -rf "$DEST"
mkdir -p "$DEST"/{docs,device,tools}

cp "$ROOT/docs/BUILD_NOTES.md" "$DEST/docs/BUILD_NOTES.md"
cp "$ROOT/docs/XDA_DRAFT.md" "$DEST/docs/XDA_POST_DRAFT.md"
cp "$ROOT/device/nevada-kernel.lock" "$DEST/device/nevada-kernel.lock"
cp "$ROOT/tools/build_nevada_ksun_susfs.sh" "$DEST/tools/build_nevada_ksun_susfs.sh"

cat > "$DEST/.gitignore" <<'EOF'
out/
kernel-src/
*.img
*.bin
*.zip
*.tar
*.tar.gz
*.ko
.config
.config.old
EOF

cat > "$DEST/README.md" <<'EOF'
# Moto G 2026 XT2613-1 (nevada) KernelSU Next + SUSFS

Reproducible KernelSU Next + SUSFS bring-up for the Motorola Moto G (2026) XT2613-1.

## Status

Work in progress. The exact stock GKI baseline has been identified and matched byte-for-byte. KernelSU Next + SUSFS integration is in the build/test phase.

## Exact baseline

- Device: XT2613-1
- Product / board: nevada
- Android codename: utah
- Firmware: W1WNS36.18-114-1
- Kernel: 5.15.180-android13-8-00018-g9b2308ac0ad6-ab14563692
- ACK tag: android13-5.15-2025-05_r14
- ACK commit: 9b2308ac0ad616788fb57ba688aa07f0ff221355
- Android CI build: 14563692
- Compiler: Android clang 14.0.7 / r450784e
- Stock GKI SHA-256: 58af5a627c5ade83fb0eca1cfc8da502fd2c07bcce162f3dfdd006a8102d27de

See [docs/BUILD_NOTES.md](docs/BUILD_NOTES.md) for the discovery and build record.

## Important

This repository intentionally does not redistribute Motorola proprietary firmware images. Supply your own matching stock images and verify them before repacking or flashing.

Do not flash artifacts from this repository to other Motorola models merely because they share the same SoC.

## Build

```bash
chmod +x tools/build_nevada_ksun_susfs.sh
./tools/build_nevada_ksun_susfs.sh
```

The resulting kernel is not intended to be flashed raw. It must be repacked into the verified Nevada Android boot-v4 image and validated first.

## XDA

A release-thread draft is maintained in [docs/XDA_POST_DRAFT.md](docs/XDA_POST_DRAFT.md). It should be published only after the first boot-tested image and recovery procedure are confirmed.
EOF

cd "$DEST"
git init -b main
git add .
git -c user.name="Nevada Kernel Project" -c user.email="noreply@local" commit -m "Initial Nevada KernelSU Next SUSFS bring-up"

echo
echo "Public repository staged at:"
echo "  $DEST"
echo
echo "No Motorola firmware images were copied."

if [[ "${2:-}" == "--publish" ]]; then
  command -v gh >/dev/null || {
    echo "gh CLI is required for --publish." >&2
    exit 2
  }
  gh repo create "$NAME" --public --source . --remote origin --push     --description "KernelSU Next + SUSFS for Motorola Moto G 2026 XT2613-1 (nevada)"
fi
