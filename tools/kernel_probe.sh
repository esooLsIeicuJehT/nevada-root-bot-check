#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="${1:-$ROOT/out/stock-analysis/boot/kernel}"
OUT="$ROOT/out/kernel-probe"
mkdir -p "$OUT"
[[ -f "$KERNEL" ]] || { echo "Missing extracted kernel: $KERNEL" >&2; exit 1; }

file "$KERNEL" | tee "$OUT/file.txt"
sha256sum "$KERNEL" | tee "$OUT/SHA256SUM"

python3 - "$KERNEL" "$OUT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); out=Path(sys.argv[2])
b=p.read_bytes()
sigs={
 "gzip":b"\x1f\x8b\x08","xz":b"\xfd7zXZ\x00","lz4_legacy":b"\x02\x21\x4c\x18",
 "lz4_frame":b"\x04\x22\x4d\x18","zstd":b"\x28\xb5\x2f\xfd",
 "bzip2":b"BZh","arm64_image_magic":b"ARM\x64",
}
lines=[]
for n,s in sigs.items():
    hits=[]; start=0
    while True:
        i=b.find(s,start)
        if i<0: break
        hits.append(i); start=i+1
    lines.append(f"{n}: "+(", ".join(hex(x) for x in hits[:32]) if hits else "not found"))
(out/"signatures.txt").write_text("\n".join(lines)+"\n")
print("\n".join(lines))
PY

strings -a "$KERNEL" | grep -E 'Linux version|clang version|Android|android1[234]|5\.15\.|IKCFG|CONFIG_' | head -n 300 > "$OUT/strings-interesting.txt" || true

if command -v extract-ikconfig >/dev/null 2>&1; then
  extract-ikconfig "$KERNEL" > "$OUT/config" 2>"$OUT/ikconfig.err" || true
elif [[ -x /usr/src/linux/scripts/extract-ikconfig ]]; then
  /usr/src/linux/scripts/extract-ikconfig "$KERNEL" > "$OUT/config" 2>"$OUT/ikconfig.err" || true
fi

echo "Kernel probe complete: $OUT"
