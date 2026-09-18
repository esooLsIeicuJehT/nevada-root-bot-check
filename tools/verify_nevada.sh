#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need=(flashfile.xml boot.img init_boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img)
for f in "${need[@]}"; do [[ -f "$f" ]] || { echo "FAIL missing $f"; exit 1; }; done

grep -q 'phone_model model="nevada_g_sys"' flashfile.xml || { echo "FAIL flashfile is not nevada_g_sys"; exit 1; }
grep -q 'W1WNS36.18-114-1' flashfile.xml || { echo "FAIL unexpected stock build"; exit 1; }

python3 - <<'PY'
import hashlib, re, sys
from pathlib import Path
xml=Path("flashfile.xml").read_text()
targets=["boot.img","init_boot.img","vendor_boot.img","dtbo.img","vbmeta.img","vbmeta_system.img"]
bad=False
for name in targets:
    m=re.search(r'MD5="([0-9a-fA-F]{32})" filename="'+re.escape(name)+r'"',xml)
    if not m:
        print(f"FAIL no XML MD5 for {name}"); bad=True; continue
    expected=m.group(1).lower()
    h=hashlib.md5()
    with open(name,"rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
    actual=h.hexdigest()
    status="OK" if actual==expected else "FAIL"
    print(f"{status:4} {name:18} {actual} expected={expected}")
    bad |= actual != expected
sys.exit(1 if bad else 0)
PY

if command -v avbtool >/dev/null 2>&1; then
  info="$(avbtool info_image --image vbmeta.img 2>/dev/null || true)"
  grep -q 'nevada_50' <<<"$info" || { echo "FAIL vbmeta HAB_META is not nevada_50"; exit 1; }
  grep -q 'motorola/nevada_' <<<"$info" || { echo "FAIL vbmeta lacks Nevada fingerprints"; exit 1; }
  echo "OK   vbmeta identity: Nevada"
else
  echo "WARN avbtool unavailable; skipped vbmeta identity check"
fi

echo "PASS: stock boot-chain files match Nevada W1WNS36.18-114-1 metadata."
