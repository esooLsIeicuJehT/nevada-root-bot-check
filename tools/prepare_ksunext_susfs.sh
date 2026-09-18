#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="${KERNEL:-$ROOT/kernel-src/android13-5.15}"
SUSFS="${SUSFS:-$ROOT/kernel-src/susfs4ksu}"

EXPECTED_GKI_COMMIT="9b2308ac0ad616788fb57ba688aa07f0ff221355"
KSUN_REPO="https://github.com/pershoot/KernelSU-Next.git"
KSUN_BRANCH="dev-susfs"
KSUN_COMMIT="5dfc3359e1cf2f4d953c74205c8d06e6eaadbec0"
SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu.git"
SUSFS_BRANCH="gki-android13-5.15"

[[ -d "$KERNEL/.git" ]] || { echo "Missing kernel tree: $KERNEL" >&2; exit 1; }
cd "$KERNEL"

actual="$(git rev-parse HEAD)"
[[ "$actual" == "$EXPECTED_GKI_COMMIT" ]] || {
  echo "Wrong GKI commit: $actual" >&2
  echo "Expected: $EXPECTED_GKI_COMMIT" >&2
  exit 1
}
[[ "$(make -s kernelversion)" == "5.15.180" ]] || {
  echo "Kernel version is not 5.15.180" >&2
  exit 1
}
echo "[1/5] Exact Nevada GKI baseline confirmed."

DRIVERS="$KERNEL/drivers"

cleanup_ksu_integration() {
  rm -f "$DRIVERS/kernelsu"
  sed -i '/obj-$(CONFIG_KSU) += kernelsu\//d' "$DRIVERS/Makefile"
  sed -i '/source "drivers\/kernelsu\/Kconfig"/d' "$DRIVERS/Kconfig"
  rm -rf "$KERNEL/KernelSU-Next"
}

need_ksu=1
if [[ -d "$KERNEL/KernelSU-Next/.git" ]]; then
  current="$(git -C "$KERNEL/KernelSU-Next" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$current" == "$KSUN_COMMIT" ]] && grep -q 'config KSU_SUSFS' "$KERNEL/KernelSU-Next/kernel/Kconfig"; then
    need_ksu=0
  fi
fi

if [[ "$need_ksu" -eq 1 ]]; then
  echo "[2/5] Replacing generic KernelSU Next with SUSFS-native dev-susfs integration..."
  cleanup_ksu_integration

  git clone --no-checkout "$KSUN_REPO" "$KERNEL/KernelSU-Next"
  git -C "$KERNEL/KernelSU-Next" fetch --depth=1 origin "$KSUN_COMMIT"
  git -C "$KERNEL/KernelSU-Next" checkout --detach "$KSUN_COMMIT"

  ln -s "$(realpath --relative-to="$DRIVERS" "$KERNEL/KernelSU-Next/kernel")" "$DRIVERS/kernelsu"
  grep -q 'obj-$(CONFIG_KSU) += kernelsu/' "$DRIVERS/Makefile" ||
    printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$DRIVERS/Makefile"
  grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVERS/Kconfig" ||
    sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' "$DRIVERS/Kconfig"
else
  echo "[2/5] SUSFS-native KernelSU Next already installed."
fi

grep -q 'config KSU_SUSFS' "$KERNEL/KernelSU-Next/kernel/Kconfig" || {
  echo "KernelSU Next checkout does not expose CONFIG_KSU_SUSFS." >&2
  exit 2
}
echo "      KernelSU Next dev-susfs: $(git -C "$KERNEL/KernelSU-Next" rev-parse --short=12 HEAD)"

if [[ ! -d "$SUSFS/.git" ]]; then
  git clone --depth=1 --branch "$SUSFS_BRANCH" "$SUSFS_REPO" "$SUSFS"
else
  git -C "$SUSFS" fetch --depth=1 origin "$SUSFS_BRANCH"
  git -C "$SUSFS" checkout "$SUSFS_BRANCH"
  git -C "$SUSFS" reset --hard "origin/$SUSFS_BRANCH"
fi
echo "[3/5] SUSFS source ready: $(git -C "$SUSFS" rev-parse --short=12 HEAD)"

KERNEL_PATCH="$SUSFS/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch"
[[ -f "$KERNEL_PATCH" ]] || {
  echo "Missing Android13-5.15 SUSFS kernel patch: $KERNEL_PATCH" >&2
  exit 3
}
[[ -f "$SUSFS/kernel_patches/fs/susfs.c" ]] || { echo "Missing fs/susfs.c" >&2; exit 3; }
[[ -f "$SUSFS/kernel_patches/include/linux/susfs.h" ]] || { echo "Missing include/linux/susfs.h" >&2; exit 3; }

echo "[4/5] Dry-running Android13-5.15 SUSFS kernel patch..."
tmp="$(mktemp)"
set +e
(
  cd "$KERNEL"
  patch --dry-run --batch --forward -p1 < "$KERNEL_PATCH"
) >"$tmp" 2>&1
rc=$?
set -e
cat "$tmp"
rm -f "$tmp"

if [[ "$rc" -ne 0 ]]; then
  echo
  echo "STOP: kernel-side SUSFS patch still needs adaptation for ACK 5.15.180 r14."
  echo "No SUSFS kernel patch was applied."
  exit 4
fi

echo "[5/5] PASS"
echo "KernelSU Next dev-susfs is integrated."
echo "Android13-5.15 SUSFS kernel patch dry-run succeeded."
echo "No SUSFS kernel filesystem patch has been applied yet."
