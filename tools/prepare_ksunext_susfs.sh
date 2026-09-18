#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="${KERNEL:-$ROOT/kernel-src/android13-5.15}"
SUSFS="${SUSFS:-$ROOT/kernel-src/susfs4ksu}"
EXPECTED_COMMIT="9b2308ac0ad616788fb57ba688aa07f0ff221355"
KSUN_TAG="v3.3.0"
SUSFS_BRANCH="gki-android13-5.15"

[[ -d "$KERNEL/.git" ]] || { echo "Missing kernel tree: $KERNEL" >&2; exit 1; }
cd "$KERNEL"

actual="$(git rev-parse HEAD)"
[[ "$actual" == "$EXPECTED_COMMIT" ]] || {
  echo "Wrong kernel commit: $actual" >&2
  echo "Expected: $EXPECTED_COMMIT" >&2
  exit 1
}

[[ "$(make -s kernelversion)" == "5.15.180" ]] || {
  echo "Kernel version is not 5.15.180" >&2
  exit 1
}

echo "[1/4] Exact Nevada GKI baseline confirmed."

if [[ ! -d "$KERNEL/KernelSU-Next/.git" ]]; then
  curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/$KSUN_TAG/kernel/setup.sh" |
    bash -s "$KSUN_TAG"
else
  echo "[2/4] KernelSU-Next already present; leaving it untouched."
fi

if [[ ! -d "$SUSFS/.git" ]]; then
  git clone --depth=1 --branch "$SUSFS_BRANCH"     https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS"
else
  git -C "$SUSFS" fetch --depth=1 origin "$SUSFS_BRANCH"
  git -C "$SUSFS" checkout "$SUSFS_BRANCH"
  git -C "$SUSFS" reset --hard "origin/$SUSFS_BRANCH"
fi

echo "[3/4] SUSFS source ready: $(git -C "$SUSFS" rev-parse --short=12 HEAD)"

KSU_PATCH="$SUSFS/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
KERNEL_PATCH="$(find "$SUSFS/kernel_patches" -maxdepth 1 -type f -name '50_add_susfs*5.15*.patch' | head -n1)"
if [[ -z "$KERNEL_PATCH" ]]; then
  KERNEL_PATCH="$(find "$SUSFS/kernel_patches" -maxdepth 1 -type f -name '50_add_susfs*.patch' | head -n1)"
fi

[[ -f "$KSU_PATCH" ]] || { echo "Missing SUSFS KernelSU patch." >&2; exit 1; }
[[ -n "$KERNEL_PATCH" && -f "$KERNEL_PATCH" ]] || { echo "Missing SUSFS 5.15 kernel patch." >&2; exit 1; }

echo
echo "Dry-running SUSFS patches before touching source..."
(
  cd "$KERNEL/KernelSU-Next"
  patch --dry-run -p1 < "$KSU_PATCH"
)
(
  cd "$KERNEL"
  patch --dry-run -p1 < "$KERNEL_PATCH"
)

echo
echo "PASS: KernelSU Next and SUSFS patches are structurally compatible."
echo "No SUSFS patch has been applied yet."
echo "Kernel patch: $KERNEL_PATCH"
echo "[4/4] Preparation complete."
