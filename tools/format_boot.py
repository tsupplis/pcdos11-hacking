#!/usr/bin/env python3
"""Extract, verify, or replace the embedded boot template in this FORMAT image.

Replacement is explicit and writes a separate output. FORMAT itself patches
sector bytes 03h..04h to CHS 0103h for double-sided media. A replacement must
retain that parameter contract; it cannot be an arbitrary modern boot sector.
"""
import argparse
from pathlib import Path

BOOT_OFFSET = 0xBE8
BOOT_SIZE = 512
FORMAT_SIZE = 3816


def read_format(path):
    data = path.read_bytes()
    if len(data) != FORMAT_SIZE:
        raise ValueError(f'{path}: expected {FORMAT_SIZE} bytes, got {len(data)}')
    validate_boot(data[BOOT_OFFSET:BOOT_OFFSET + BOOT_SIZE])
    return data


def validate_boot(data):
    if len(data) != BOOT_SIZE:
        raise ValueError(f'boot image must be exactly {BOOT_SIZE} bytes')
    if data[:3] != bytes.fromhex('EB 27 90'):
        raise ValueError('boot image must retain the FORMAT parameter header (EB 27 90)')
    if data[-2:] != bytes.fromhex('55 AA'):
        raise ValueError('boot image must retain the 55 AA signature')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for action in ('extract', 'check', 'inject'):
        p = sub.add_parser(action)
        p.add_argument('format', type=Path)
        if action != 'extract':
            p.add_argument('boot', type=Path)
        if action != 'check':
            p.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        image = read_format(args.format)
        sector = image[BOOT_OFFSET:BOOT_OFFSET + BOOT_SIZE]
        if args.command == 'check':
            boot = args.boot.read_bytes()
            validate_boot(boot)
            if boot != sector:
                raise ValueError('rebuilt boot sector differs from the embedded reference')
            print('Boot sector matches: 512 bytes at FORMAT file offset 0BE8h')
            return
        if args.output.resolve() == args.format.resolve():
            raise ValueError('output must be a separate file from the FORMAT input')
        if args.command == 'extract':
            result = sector
        else:
            boot = args.boot.read_bytes()
            validate_boot(boot)
            if args.output.resolve() == args.boot.resolve():
                raise ValueError('output must be a separate file from the boot input')
            result = image[:BOOT_OFFSET] + boot + image[BOOT_OFFSET + BOOT_SIZE:]
        args.output.write_bytes(result)
        print(f'Wrote {len(result)} bytes to {args.output}')
    except (OSError, ValueError) as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()
