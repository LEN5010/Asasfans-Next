#!/usr/bin/env bash
# Renders the real widgets headlessly and writes PNGs plus a manifest.
#
#   tool/visual_capture.sh <out-dir> [test file ...]
#
# Needs a CJK font on this machine (or ASASFANS_CJK_FONT=<path>); without one
# the tests still run but write nothing. The images show the Solid material
# on flutter_tester's software rasterizer: layout evidence, not device optics.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:?usage: tool/visual_capture.sh <out-dir> [test ...]}"
shift || true
tests=("$@")
[ ${#tests[@]} -eq 0 ] && tests=(test/visual/current_pages_test.dart)
commit="$(git rev-parse HEAD)"
git diff --quiet HEAD -- lib test || commit="$commit+dirty"
rm -rf "$out"
mkdir -p "$out"
ASASFANS_VISUAL_OUT="$(cd "$out" && pwd)" ASASFANS_VISUAL_COMMIT="$commit" \
  tool/flutterw test --no-pub "${tests[@]}"
python3 - "$out" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
entries = []
for sidecar in sorted(out.glob('*.png.json')):
    entries.append(json.loads(sidecar.read_text()))
    sidecar.unlink()
(out / 'manifest.json').write_text(
    json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
print(f'{len(entries)} screenshots in {out}')
PY
