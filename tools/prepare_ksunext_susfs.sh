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

classify_patch() {
  local tree="$1"
  local patchfile="$2"

  if git -C "$tree" apply --check "$patchfile" >/dev/null 2>&1; then
    echo "APPLIES"
  elif git -C "$tree" apply --reverse --check "$patchfile" >/dev/null 2>&1; then
    echo "REVERSE_MATCH"
  else
    echo "CONFLICT"
  fi
}

echo
echo "Checking SUSFS patches non-interactively..."
ksu_state="$(classify_patch "$KERNEL/KernelSU-Next" "$KSU_PATCH")"
kernel_state="$(classify_patch "$KERNEL" "$KERNEL_PATCH")"

echo "KernelSU-Next patch: $ksu_state"
echo "GKI 5.15 kernel patch: $kernel_state"
echo "Kernel patch: $KERNEL_PATCH"

case "$ksu_state" in
  APPLIES)
    echo "OK: SUSFS KernelSU patch can be applied cleanly."
    ;;
  REVERSE_MATCH)
    echo "STOP: SUSFS KernelSU patch matches in reverse against KernelSU Next."
    echo "Do NOT reverse it. This usually means the current KernelSU Next tree already contains overlapping changes or the patch targets a different KernelSU baseline."
    exit 2
    ;;
  CONFLICT)
    echo "STOP: SUSFS KernelSU patch does not cleanly apply to KernelSU Next $KSUN_TAG."
    echo "It needs a KernelSU-Next-specific adaptation before we modify source."
    exit 3
    ;;
esac

case "$kernel_state" in
  APPLIES)
    echo "OK: SUSFS Android 13 / 5.15 kernel patch can be applied cleanly."
    ;;
  REVERSE_MATCH)
    echo "STOP: GKI kernel patch appears already applied or reverse-compatible. Do NOT reverse it."
    exit 4
    ;;
  CONFLICT)
    echo "STOP: SUSFS GKI 5.15 patch conflicts with this exact ACK tree."
    exit 5
    ;;
esac

echo
echo "PASS: both patches can be applied cleanly."
echo "No SUSFS patch has been applied yet."
echo "[4/4] Preparation complete."
