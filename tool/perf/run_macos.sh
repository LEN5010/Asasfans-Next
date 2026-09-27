#!/usr/bin/env bash
# One Profile run of tool/perf/main.dart on this Mac.
#
#   tool/perf/run_macos.sh <label> <out-dir> [smooth|auto|visual] [scroll-seconds]
#
# Builds the perf entry in profile mode, starts the executable directly (so
# its PID is known), samples the host's own view of its memory every two
# seconds with `footprint`, and leaves <label>.json (the app's frame and
# image numbers), <label>.footprint.txt and <label>.log in <out-dir>.
# Offline and in memory: the run reads no personal data and no network.
set -euo pipefail
cd "$(dirname "$0")/../.."
label="${1:?usage: run_macos.sh <label> <out-dir> [glass] [seconds]}"
out="${2:?usage: run_macos.sh <label> <out-dir> [glass] [seconds]}"
glass="${3:-auto}"
seconds="${4:-60}"
commit="$(git rev-parse --short HEAD)"
git diff --quiet HEAD -- lib tool/perf || commit="$commit+dirty"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

tool/flutterw build macos --profile --no-pub -t tool/perf/main.dart \
  --dart-define=ASASFANS_PERF_GLASS="$glass" \
  --dart-define=ASASFANS_PERF_LABEL="$label" \
  --dart-define=ASASFANS_PERF_COMMIT="$commit" \
  --dart-define=ASASFANS_PERF_SCROLL_SECONDS="$seconds" \
  >"$out/$label.build.log" 2>&1

bundle="build/macos/Build/Products/Profile/Asasfans Next.app"
"$bundle/Contents/MacOS/Asasfans Next" >"$out/$label.log" 2>&1 &
pid=$!
# Started from a shell, the window may open behind others; bring the running
# instance to the front (the app waits until it is resumed).
sleep 2
open "$bundle" || true
: >"$out/$label.footprint.txt"
while kill -0 "$pid" 2>/dev/null; do
  {
    date +%s
    footprint --noCategories -p "$pid" 2>/dev/null | grep -E 'Footprint|phys_footprint' || true
  } >>"$out/$label.footprint.txt"
  sleep 2
done
wait "$pid" || true
grep -o 'PERF_RESULT .*' "$out/$label.log" | sed 's/^PERF_RESULT //' >"$out/$label.json"
python3 - "$out/$label.json" "$out/$label.footprint.txt" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
def mb(kind):
    return [float(v) * {'KB': 1 / 1024, 'MB': 1, 'GB': 1024}[u]
            for v, u in re.findall(kind + r':\s*([\d.]+)\s*(KB|MB|GB)', text)]
text = open(sys.argv[2]).read()
now, peak = mb('phys_footprint'), mb('phys_footprint_peak')
data['host_footprint_mb'] = {'samples': len(now), 'max_sampled': max(now, default=None),
                             'peak_reported': peak[-1] if peak else None}
json.dump(data, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
print(sys.argv[1], 'phases:', len(data['phases']), 'footprint MB:', data['host_footprint_mb'])
PY
