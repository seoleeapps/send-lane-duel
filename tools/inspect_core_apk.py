#!/usr/bin/env python3
"""Inspect actual Core APK resources and ARM64 16KB alignment without extracting files."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def inspect(apk):
    forbidden = ('build/', '.github/', 'docs/', 'tests/', 'tools/', 'scripts/', 'firebase/', 'release/',
                 'assets/art/concepts/', 'assets/art/raw/', 'assets/art/style/', 'assets/art/asset-manifest.json', 'assets/audio/sound-manifest.json')
    libraries = []
    with zipfile.ZipFile(apk) as archive, apk.open('rb') as raw:
        assets = [entry for entry in archive.infolist() if entry.filename.startswith('assets/')]
        unwanted = [entry.filename for entry in assets if entry.filename[7:].startswith(forbidden)]
        if unwanted:
            raise ValueError('Excluded resources bundled: ' + ', '.join(unwanted))
        for entry in archive.infolist():
            if not entry.filename.startswith('lib/') or not entry.filename.endswith('.so'):
                continue
            if not entry.filename.startswith('lib/arm64-v8a/'):
                raise ValueError('Core APK must contain only ARM64 libraries')
            elf = archive.read(entry)
            if elf[:6] != b'\x7fELF\x02\x01':
                raise ValueError('Expected little-endian ELF64: ' + entry.filename)
            offset = struct.unpack_from('<Q', elf, 32)[0]
            size, count = struct.unpack_from('<HH', elf, 54)
            aligns = [struct.unpack_from('<Q', elf, offset + i * size + 48)[0]
                      for i in range(count) if struct.unpack_from('<I', elf, offset + i * size)[0] == 1]
            if not aligns or any(value < 16384 for value in aligns):
                raise ValueError('ELF LOAD alignment below 16KB: ' + entry.filename)
            raw.seek(entry.header_offset + 26)
            name_len, extra_len = struct.unpack('<HH', raw.read(4))
            data_offset = entry.header_offset + 30 + name_len + extra_len
            if entry.compress_type == zipfile.ZIP_STORED and data_offset % 16384:
                raise ValueError('Uncompressed library ZIP alignment below 16KB: ' + entry.filename)
            libraries.append({'library': entry.filename, 'loadAlignments': aligns})
        if not libraries:
            raise ValueError('No native libraries')
        return {'passed': True, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
                'bytes': apk.stat().st_size, 'resourceCount': len(assets), 'unwantedResources': [],
                'resourceCompressedBytes': sum(entry.compress_size for entry in assets), 'libraries': libraries}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = inspect(args.apk)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    print('APK resource exclusions and ARM64 ZIP/ELF 16KB alignment PASS')
