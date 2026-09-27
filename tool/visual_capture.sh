#!/usr/bin/env bash
# Renders the real widgets headlessly and writes PNGs plus a manifest.
#
#   tool/visual_capture.sh <out-dir> [test file ...]
#   ASASFANS_VISUAL_IMPELLER=1 tool/visual_capture.sh <out-dir> [test ...]
#
# Needs a CJK font on this machine (or ASASFANS_CJK_FONT=<path>); without one
# the tests still run but write nothing. By default the images show the Solid
# material on flutter_tester's software rasterizer: layout evidence, not
# device optics. With ASASFANS_VISUAL_IMPELLER=1 flutter_tester draws with
# Impeller on this machine, so glass tiers render; still no app window and
# no frame time. Clips (frames/<clip>/) become <clip>.mp4 when ffmpeg exists.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:?usage: tool/visual_capture.sh <out-dir> [test ...]}"
shift || true
tests=("$@")
[ ${#tests[@]} -eq 0 ] && tests=(test/visual/current_pages_test.dart)
commit="$(git rev-parse HEAD)"
git diff --quiet HEAD -- lib test || commit="$commit+dirty"
flags=()
if [ -n "${ASASFANS_VISUAL_IMPELLER:-}" ]; then
  flags=(--enable-impeller)
  # liquid_glass_widgets loads its premium shaders from the bundle root
  # whenever FLUTTER_TEST is set, as in its own repository. In this app's
  # bundle they sit under packages/; build the bundle, then copy them up.
  assets=build/unit_test_assets
  if [ ! -d "$assets/packages/liquid_glass_widgets/shaders" ]; then
    tool/flutterw test --no-pub --enable-impeller test/visual/glass_tiers_test.dart \
      --plain-name 'no test has this name' >/dev/null 2>&1 || true
  fi
  mkdir -p "$assets/shaders"
  cp "$assets"/packages/liquid_glass_widgets/shaders/liquid_glass_*.frag "$assets/shaders/"
fi
rm -rf "$out"
mkdir -p "$out"
ASASFANS_VISUAL_OUT="$(cd "$out" && pwd)" ASASFANS_VISUAL_COMMIT="$commit" \
  tool/flutterw test --no-pub ${flags[@]+"${flags[@]}"} "${tests[@]}"
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
if [ -d "$out/frames" ]; then
  if command -v ffmpeg >/dev/null; then
    for clip in "$out"/frames/*/; do
      name="$(basename "$clip")"
      # Frames are 16 ms apart in app time: 60 per second plays them at pace.
      ffmpeg -loglevel error -y -framerate 60 -i "$clip%04d.png" \
        -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' -pix_fmt yuv420p "$out/$name.mp4"
    done
    rm -rf "$out/frames"
    echo "$(ls "$out"/*.mp4 | wc -l | tr -d ' ') clips in $out"
  else
    echo "ffmpeg not found; frames kept in $out/frames"
  fi
fi
