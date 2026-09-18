#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="$ROOT/kernel-src/android13-5.15"
TOOLCHAIN_ROOT="$ROOT/kernel-src/clang-r450784e-prebuilt"
TOOLCHAIN="$TOOLCHAIN_ROOT/clang-r450784e"
OUT="$ROOT/out/ksun-susfs"

EXPECTED_COMMIT="9b2308ac0ad616788fb57ba688aa07f0ff221355"

[[ -d "$KERNEL/.git" ]] || { echo "Missing kernel tree: $KERNEL" >&2; exit 1; }
[[ "$(git -C "$KERNEL" rev-parse HEAD)" == "$EXPECTED_COMMIT" ]] || {
  echo "Kernel tree is not pinned to expected r14 commit." >&2
  exit 1
}

if [[ ! -x "$TOOLCHAIN/bin/clang" ]]; then
  echo "[toolchain] Fetching Android clang-r450784e..."
  rm -rf "$TOOLCHAIN_ROOT"
  git clone --depth=1 --filter=blob:none --sparse     --branch android-13.0.0_r0.65     https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86     "$TOOLCHAIN_ROOT"
  git -C "$TOOLCHAIN_ROOT" sparse-checkout set clang-r450784e
fi

export PATH="$TOOLCHAIN/bin:$PATH"
export ARCH=arm64
export LLVM=1
export LLVM_IAS=1

echo "=== TOOLCHAIN ==="
clang --version | head -2

mkdir -p "$OUT"

echo "=== DEFCONFIG ==="
make -C "$KERNEL" O="$OUT" gki_defconfig

"$KERNEL/scripts/config" --file "$OUT/.config"   -e KSU   -e KSU_SUSFS

make -C "$KERNEL" O="$OUT" olddefconfig

echo "=== ENABLED ==="
grep -E '^(CONFIG_KSU|CONFIG_KSU_SUSFS)=' "$OUT/.config"

echo "=== BUILD ==="
make -C "$KERNEL" O="$OUT" -j"$(nproc)" Image Image.gz

IMAGE="$OUT/arch/arm64/boot/Image"
IMAGE_GZ="$OUT/arch/arm64/boot/Image.gz"

echo
echo "=== RESULT ==="
file "$IMAGE"
sha256sum "$IMAGE" "$IMAGE_GZ"
ls -lh "$IMAGE" "$IMAGE_GZ"

echo
echo "Build complete."
echo "Image:    $IMAGE"
echo "Image.gz: $IMAGE_GZ"
