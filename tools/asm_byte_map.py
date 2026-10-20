#!/usr/bin/env python3
"""Check byte-exact rebuilds and source maps without hexadecimal source comments.

Tables retain verified instruction boundaries. Regeneration refreshes statements
and source locations after documentation/label edits, and derives data lengths
from DB/DW declarations. A changed instruction count or offset requires a new
mapping rather than silently reusing the old instruction boundaries.
"""
import argparse
import ast
import csv
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = ['file_offset_hex', 'com_address_hex', 'runtime_address_hex', 'length',
          'kind', 'source_file', 'source_line', 'bytes_hex', 'assembly']


def statement_text(line):
    """Strip a comment while retaining semicolons inside quoted DB strings."""
    quote = None
    for index, char in enumerate(line):
        if char in ('"', "'"):
            quote = None if quote == char else char if quote is None else quote
        elif char == ';' and quote is None:
            return line[:index].strip()
    return line.strip()


def source_statements(filename, *, msver=False, boot_only=False, in_boot=False):
    conditions = []
    in_macro = False
    for lineno, line in enumerate((ROOT / filename).read_text().splitlines(), 1):
        statement = statement_text(line)
        lower = statement.lower()
        if re.match(r'^\w+\s+macro\b', lower):
            in_macro = True
        if in_macro:
            if lower == 'endm':
                in_macro = False
            continue
        if lower in ('if msver', 'if ibmver'):
            conditions.append(msver if lower == 'if msver' else not msver)
            continue
        if lower == 'else' and conditions:
            conditions[-1] = not conditions[-1]
            continue
        if lower == 'endif' and conditions:
            conditions.pop()
            continue
        if conditions and not all(conditions):
            continue
        if lower.startswith('include '):
            included = statement.split()[1]
            if included not in ('format.asm', 'bootsect.asm', 'fmtboot.inc', 'ibmboot.asm'):
                raise ValueError(f'unsupported include: {included}')
            yield from source_statements(included, msver=msver, boot_only=boot_only,
                                         in_boot=included == 'fmtboot.inc')
            continue
        if not statement or statement.endswith(':'):
            continue
        if re.match(r'^\w+\s+(?:equ|label|segment|ends)\b', lower):
            continue
        if re.match(r'^(?:assume|org|end)\b', lower):
            continue
        yield filename, lineno, statement, in_boot


def data_size(statement):
    op, values = statement.split(None, 1)
    # Parse comma-separated literals without splitting a comma inside a string.
    tokens = re.findall(r'"[^"]*"|\'[^\']*\'|[^,]+', values)
    if op.lower() == 'dw':
        return 2 * len(tokens)
    total = 0
    for token in tokens:
        token = token.strip()
        total += len(ast.literal_eval(token).encode('ascii')) if token.startswith(('"', "'")) else 1
    return total


def read_records(path):
    with path.open() as stream:
        return list(csv.DictReader(stream, delimiter='\t'))


def validate_reference_records(records, image, name):
    cursor = 0
    for record in records:
        data = bytes.fromhex(record['bytes_hex'])
        if (int(record['file_offset_hex'], 16) != cursor or
                len(data) != int(record['length']) or
                image[cursor:cursor + len(data)] != data):
            raise ValueError(f'{name}: invalid reference coverage at {cursor:04X}h')
        cursor += len(data)
    if cursor != len(image):
        raise ValueError(f'{name}: mapped {cursor} of {len(image)} bytes')


def audit(name, check):
    reference = {'ibmfmt': 'format', 'msfmt': 'msformat',
                 'ibmboot': 'format', 'fmtboot': 'format', 'msboot': 'msformat'}.get(name, name)
    extension = '.exe' if name == 'exe2bin' else '.com'
    image = (ROOT / 'reference' / (reference + extension)).read_bytes()
    boot_only = name in ('ibmboot', 'fmtboot', 'msboot')
    if boot_only:
        image = image[0xBE8:0xDE8]
    built = ROOT / (name + ('.bin' if boot_only else extension))
    if built.read_bytes() != image:
        raise ValueError(f'{built.name}: rebuilt bytes differ from the reference')
    target = ROOT / 'mappings' / f'{name}.tsv'
    old = read_records(target)
    validate_reference_records(old, image, name)
    if name == 'chkdsk':
        print(f'{name}: {len(image)} mapped bytes intact; rebuilt binary matches')
        return
    instructions = iter(row for row in old if row['kind'] == 'code')
    cursor = 0
    rows = []
    for filename, lineno, statement, in_boot in source_statements(
            name + '.asm', msver=name in ('msfmt', 'msboot'), boot_only=boot_only):
        data = statement.split()[0].lower() in ('db', 'dw')
        if data:
            length = data_size(statement)
        else:
            previous = next(instructions, None)
            if previous is None or int(previous['file_offset_hex'], 16) != cursor:
                raise ValueError(f'{filename}:{lineno}: instruction boundaries changed; remap required')
            length = int(previous['length'])
        raw = image[cursor:cursor + length]
        if len(raw) != length:
            raise ValueError(f'{filename}:{lineno}: source exceeds reference image')
        runtime = 0x7C00 + cursor - (0 if boot_only else 0xBE8) if in_boot else cursor + 0x100
        if name == 'exe2bin':
            # MZ header, CS-relative code, DS-relative data, and preserved overlay.
            runtime = cursor - (0x200 if cursor < 0x3CA else 0x3C0)
            runtime_text = f'{runtime:04X}' if 0x200 <= cursor < 0x4CC else ''
        else:
            runtime_text = f'{runtime:04X}'
        rows.append([f'{cursor:04X}', '' if boot_only or name == 'exe2bin' else f'{cursor + 0x100:04X}',
                     runtime_text, length, 'data' if data else 'code',
                     filename, lineno, raw.hex(' ').upper(), statement])
        cursor += length
    if next(instructions, None) is not None or cursor != len(image):
        raise ValueError(f'{name}: incomplete source coverage ({cursor}/{len(image)} bytes)')
    stream = io.StringIO()
    writer = csv.writer(stream, delimiter='\t', lineterminator='\n')
    writer.writerow(HEADER)
    writer.writerows(rows)
    if check:
        if target.read_text() != stream.getvalue():
            raise ValueError(f'{target.name}: stale; run tools/asm_byte_map.py {name}')
    else:
        target.write_text(stream.getvalue())
    print(f'{name}: {cursor} bytes mapped; source locations and rebuilt binary match')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='+', choices=['diskcopy', 'diskcomp', 'chkdsk',
        'mode', 'comp', 'filcom', 'exe2bin', 'ibmfmt', 'msfmt', 'ibmboot', 'fmtboot', 'msboot'])
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        for name in args.names:
            audit(name, args.check)
    except (OSError, ValueError, SyntaxError) as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()
