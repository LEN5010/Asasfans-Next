#!/usr/bin/env python3
"""Read-only APK ZIP inventory; entry storage size is not installed size.
From the optimization plan package (docs/optimization/tools); adds dart_aot.
Usage: python audit_apk.py app.apk --output apk-report.json
No Android tools or third-party Python packages required.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

def category(name: str) -> str:
    if name.endswith('/libflutter.so'): return 'flutter_engine'
    if name.endswith('/libVkLayer_khronos_validation.so'): return 'vulkan_validation'
    if name.endswith('/kernel_blob.bin'): return 'debug_dart_kernel'
    if name.endswith('/isolate_snapshot_data') or name.endswith('/vm_snapshot_data'): return 'dart_snapshots'
    if name.endswith('/libsqlite3.so'): return 'sqlite_native'
    if name.endswith('/libapp.so'): return 'dart_aot'
    if name.startswith('lib/'): return 'other_native'
    if name.startswith('classes') and name.endswith('.dex'): return 'dex'
    if name.startswith('assets/flutter_assets/assets/'): return 'app_assets'
    if 'liquid_glass_widgets/shaders/' in name: return 'glass_shaders'
    if '/fonts/' in name or name.endswith(('.ttf', '.otf')): return 'fonts'
    return 'other'

def inspect(apk: Path) -> dict:
    digest = hashlib.sha256()
    with apk.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''): digest.update(block)
    groups = defaultdict(lambda: {'entry_count': 0, 'uncompressed_bytes': 0, 'apk_stored_bytes': 0})
    with zipfile.ZipFile(apk) as archive:
        entries = []
        for item in archive.infolist():
            if item.is_dir(): continue
            group = category(item.filename)
            entries.append({'path': item.filename, 'uncompressed_bytes': item.file_size,
                            'apk_stored_bytes': item.compress_size, 'category': group})
            groups[group]['entry_count'] += 1
            groups[group]['uncompressed_bytes'] += item.file_size
            groups[group]['apk_stored_bytes'] += item.compress_size
    stored = sum(item['apk_stored_bytes'] for item in entries)
    return {'apk_filename': apk.name, 'apk_bytes': apk.stat().st_size,
            'apk_sha256': digest.hexdigest(), 'measurement': 'APK ZIP entry stored sizes, not installed size',
            'abis': sorted({i['path'].split('/')[1] for i in entries if i['path'].startswith('lib/') and i['path'].endswith('.so')}),
            'zip_metadata_alignment_and_signing_bytes': apk.stat().st_size - stored,
            'groups': dict(groups), 'entries': sorted(entries, key=lambda x:x['apk_stored_bytes'], reverse=True)}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        report = inspect(args.apk)
        text = json.dumps(report, ensure_ascii=False, indent=2)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(text+'\n', encoding='utf-8')
        else: print(text)
    except (OSError, zipfile.BadZipFile) as error:
        print(f'APK inspection failed: {error}', file=sys.stderr)
        return 1
    return 0
if __name__ == '__main__': raise SystemExit(main())
