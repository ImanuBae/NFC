"""Check 64-bit APK ELF LOAD segments for Android 16 KB page compatibility.

Usage: python scripts/check_android_alignment.py path/to/app.apk
APK ZIP alignment is checked separately with Android SDK zipalign -c -P 16.
"""
import struct
import sys
import zipfile


def check(apk):
    count = 0
    failures = []
    with zipfile.ZipFile(apk) as archive:
        for name in archive.namelist():
            if not name.endswith('.so') or not name.startswith(('lib/arm64-v8a/', 'lib/x86_64/')):
                continue
            data = archive.read(name)
            if data[:6] != b'\x7fELF\x02\x01':
                failures.append(f'{name}: expected little-endian ELF64')
                continue
            count += 1
            offset = struct.unpack_from('<Q', data, 32)[0]
            size, number = struct.unpack_from('<HH', data, 54)
            loads = []
            for index in range(number):
                entry = offset + index * size
                if struct.unpack_from('<I', data, entry)[0] != 1:
                    continue
                file_offset, virtual_address = struct.unpack_from('<QQ', data, entry + 8)
                alignment = struct.unpack_from('<Q', data, entry + 48)[0]
                loads.append(alignment)
                if alignment < 16384 or (virtual_address - file_offset) % 16384:
                    failures.append(f'{name}: LOAD alignment {alignment:#x} does not support 16 KB')
            if not loads:
                failures.append(f'{name}: missing LOAD segments')
            print(f'{name}: ' + ', '.join(hex(value) for value in loads))
    if not count:
        failures.append('No 64-bit shared libraries found')
    if failures:
        print('\n'.join(failures), file=sys.stderr)
        return 1
    print(f'PASS: {count} ELF64 libraries support 16 KB page alignment.')
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python scripts/check_android_alignment.py APP.apk')
    raise SystemExit(check(sys.argv[1]))
