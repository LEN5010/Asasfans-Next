#!/usr/bin/env python3
"""Tabulates tool/perf runs side by side: tool/perf/compare.py <dir> [label prefix ...]

Every run of a configuration is shown, not an average: two runs of the same
build differ, and that spread is part of the result. Phases a run marked
invalid (window not frontmost) are shown as such, never as numbers.
"""
import glob, json, os, sys

folder = sys.argv[1]
runs = sorted(glob.glob(os.path.join(folder, '*.json')))
phases = ['cold/scroll', 'warm/scroll', 'cold/long-image', 'warm/long-image',
          'cold/channels-and-tabs', 'warm/channels-and-tabs']

def cell(p, part):
    if not p['valid']:
        return 'invalid'
    s = p['frames'].get(part) or {}
    if not s:
        return '-'
    return '%.1f / %.1f / %.1f (%.1f%%)' % (s['p50'], s['p95'], s['p99'], 100 * s['over_budget_ratio'])

print('Frame times in ms, P50 / P95 / P99 (share over the %s ms budget). UI and raster are separate threads; never add them.\n' % '16.7')
for phase in phases:
    print('#### %s\n' % phase)
    print('| run | commit | tier | frames | UI build | raster |')
    print('|---|---|---|---|---|---|')
    for f in runs:
        d = json.load(open(f))
        p = next(x for x in d['phases'] if x['name'] == phase)
        print('| %s | %s | %s | %d | %s | %s |' % (d['label'], d['commit'], p['glass_tier_effective'],
              p['frames']['count'], cell(p, 'ui_build'), cell(p, 'raster')))
    print()

print('#### Memory and images\n')
print('| run | host footprint max sampled / peak (MB) | RSS end of cold scroll (MB) | image cache end of cold scroll (MB) | long strip tile decode | detail decode | tap → detail image (ms) |')
print('|---|---|---|---|---|---|---|')
for f in runs:
    d = json.load(open(f))
    ph = {x['name']: x for x in d['phases']}
    s, l = ph['cold/scroll'], ph['cold/long-image']
    tile = [i['decoded'] for i in l.get('tile_images', []) if i['decoded'][1] > 1000]
    det = [i['decoded'] for i in l.get('detail_images', [])]
    fp = d['host_footprint_mb']
    print('| %s | %s / %s | %.0f | %.0f | %s | %s | %s |' % (d['label'], fp['max_sampled'], fp['peak_reported'],
          s['memory']['rss_mb'], s['memory']['image_cache_mb'],
          ' '.join('%dx%d' % tuple(t) for t in tile) or '-', ' '.join('%dx%d' % tuple(t) for t in det) or '-',
          l.get('tap_to_detail_image_ms')))
