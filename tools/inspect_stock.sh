#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/out/stock-analysis"
mkdir -p "$OUT"

FILES=(boot.img init_boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img flashfile.xml servicefile.xml)

for f in "${FILES[@]}"; do
  [[ -f "$ROOT/$f" ]] || { echo "Missing: $f" >&2; exit 1; }
done

echo "Nevada XT2613-1 stock analysis" | tee "$OUT/summary.txt"
echo "Generated: $(date -u +%FT%TZ)" | tee -a "$OUT/summary.txt"
echo | tee -a "$OUT/summary.txt"

sha256sum "${FILES[@]/#/$ROOT/}" > "$OUT/SHA256SUMS"
file "${FILES[@]/#/$ROOT/}" > "$OUT/file-types.txt"

if command -v unpack_bootimg.py >/dev/null 2>&1; then
  mkdir -p "$OUT/boot" "$OUT/init_boot" "$OUT/vendor_boot"
  unpack_bootimg.py --boot_img "$ROOT/boot.img" --out "$OUT/boot" > "$OUT/boot-header.txt" 2>&1 || true
  unpack_bootimg.py --boot_img "$ROOT/init_boot.img" --out "$OUT/init_boot" > "$OUT/init_boot-header.txt" 2>&1 || true
  unpack_bootimg.py --boot_img "$ROOT/vendor_boot.img" --out "$OUT/vendor_boot" > "$OUT/vendor_boot-header.txt" 2>&1 || true
elif command -v unpack_bootimg >/dev/null 2>&1; then
  mkdir -p "$OUT/boot" "$OUT/init_boot" "$OUT/vendor_boot"
  unpack_bootimg --boot_img "$ROOT/boot.img" --out "$OUT/boot" > "$OUT/boot-header.txt" 2>&1 || true
  unpack_bootimg --boot_img "$ROOT/init_boot.img" --out "$OUT/init_boot" > "$OUT/init_boot-header.txt" 2>&1 || true
  unpack_bootimg --boot_img "$ROOT/vendor_boot.img" --out "$OUT/vendor_boot" > "$OUT/vendor_boot-header.txt" 2>&1 || true
else
  echo "Android unpack_bootimg not found; hashes and file signatures were still generated." | tee -a "$OUT/summary.txt"
fi

if command -v avbtool >/dev/null 2>&1; then
  for f in vbmeta.img vbmeta_system.img; do
    avbtool info_image --image "$ROOT/$f" > "$OUT/$f.avb.txt" 2>&1 || true
  done
fi

echo "Analysis complete: $OUT" | tee -a "$OUT/summary.txt"
