#!/usr/bin/env python3
"""Check byte-exact rebuilds and source maps without hexadecimal source comments.

Tables retain verified instruction boundaries. Regeneration refreshes statements
and source locations after documentation/label edits, and derives data lengths
from DB/DW declarations. A changed instruction count or offset requires a new
mapping rather than silently reusing the old instruction boundaries.
"""
import argparse
import bisect
import csv
import io
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = ['file_offset_hex', 'com_address_hex', 'runtime_address_hex', 'length',
          'kind', 'source_file', 'source_line', 'bytes_hex', 'assembly']
ALIASES = {'ibmdelin': 'ibmedlin'}
SYS_VARIANTS = {'ibmsys', 'mssys'}


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
        if re.match(r'^include\s+', lower):
            included = statement.split()[1]
            if included not in ('format.asm', 'bootsect.asm', 'fmtboot.inc', 'ibmboot.asm',
                                'edlin101.asm', 'edlin102.asm', 'sys.asm'):
                raise ValueError(f'unsupported include: {included}')
            yield from source_statements(included, msver=msver, boot_only=boot_only,
                                         in_boot=included == 'fmtboot.inc')
            continue
        if not statement or statement.endswith(':'):
            continue
        if re.match(r'^\w+\s+(?:equ|label|segment|ends|proc|endp)\b', lower):
            continue
        if re.match(r'^(?:assume|org|end)\b', lower):
            continue
        yield filename, lineno, statement, in_boot


def data_statement(statement):
    """Recognize DB/DW/DD, including MASM's inline data-label syntax."""
    match = re.match(r'^(?:\w+\s+)?(db|dw|dd)\s+(.+)$', statement, re.I)
    return (match[1].lower(), match[2]) if match else None


def data_values(values):
    """Split a MASM initializer list, retaining quoted commas and nested DUP."""
    start = depth = index = 0
    quote = None
    while index < len(values):
        char = values[index]
        if quote:
            if char == quote:
                if index + 1 < len(values) and values[index + 1] == quote:
                    index += 1
                else:
                    quote = None
        elif char in ('"', "'"):
            quote = char
        elif char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
        elif char == ',' and depth == 0:
            yield values[start:index].strip()
            start = index + 1
        if depth < 0:
            raise ValueError(f'unbalanced data initializer: {values}')
        index += 1
    if quote or depth:
        raise ValueError(f'unterminated data initializer: {values}')
    yield values[start:].strip()


def data_size(statement):
    directive = data_statement(statement)
    if directive is None:
        raise ValueError(f'not a data declaration: {statement}')
    op, values = directive
    width = {'db': 1, 'dw': 2, 'dd': 4}[op]
    total = 0
    for token in data_values(values):
        duplicate = re.fullmatch(r'([0-9][0-9a-f]*h|\d+)\s+dup\s*\((.*)\)', token, re.I)
        if duplicate:
            count = duplicate[1]
            count = int(count[:-1], 16) if count.lower().endswith('h') else int(count)
            total += count * data_size(f'{op} {duplicate[2]}')
        elif re.search(r'\bdup\b', token, re.I):
            raise ValueError(f'unsupported DUP count: {token}')
        elif not token:
            raise ValueError(f'empty data initializer: {statement}')
        elif width == 1 and token.startswith(('"', "'")):
            quote = token[0]
            if token[-1] != quote:
                raise ValueError(f'unterminated string: {token}')
            total += len(token[1:-1].replace(quote * 2, quote).encode('ascii'))
        else:
            total += width
    return total


def listing_boundaries(name, statements, image, origin):
    """Bootstrap missing local maps from a current MASM 1.10 listing.

    Macro expansion rows belong to the invocation, not separate source lines.
    Numbered continuation rows for long DB strings have no new address.
    --check can use these boundaries without creating an ignored TSV file.
    """
    listing = ROOT / (('exbimage' if name == 'exe2bin' else name) + '.lst')
    build_target = name + ('.bin' if name in ('ibmboot', 'msboot') else
                           '.exe' if name == 'exe2bin' else '.com')
    if not listing.exists():
        raise ValueError(f'{listing.name}: missing; run make -B {build_target}')
    sources = {name + '.asm', *(filename for filename, _, _, _ in statements)}
    if any((ROOT / source).stat().st_mtime_ns > listing.stat().st_mtime_ns for source in sources):
        raise ValueError(f'{listing.name}: older than source; run make -B {build_target}')
    contents = listing.read_text()
    summary = re.findall(r'Errors\s+Errors\s+(\d+)\s+(\d+)', contents)
    if not summary or summary[-1] != ('0', '0'):
        raise ValueError(f'{listing.name}: MASM listing is not a clean build')
    addresses = set()
    image_length = len(image)
    expanding = False
    for line in contents.splitlines():
        if not re.match(r'^\d+\s', line):
            continue
        line = line.expandtabs(8)
        address = line[9:13]
        payload = line[14:36].strip()
        macro = '+' in line[36:40]
        if re.fullmatch(r'[0-9A-F]{4}', address) and payload:
            offset = int(address, 16) - origin
            if 0 <= offset < image_length and (not macro or not expanding):
                addresses.add(offset)
            # MASM displays operand words in numeric order, unlike byte tokens.
            # DUP rows display a repeat count, so they are not literal bytes.
            if 0 <= offset < image_length and '[' not in payload:
                encoded = bytearray()
                for token in payload.replace('/', ' ').replace(':', ' ').split():
                    if token == 'R':
                        continue
                    if not re.fullmatch(r'(?:[0-9A-F]{2}){1,4}', token):
                        raise ValueError(f'{listing.name}: unsupported byte field {payload!r}')
                    encoded.extend(int(token, 16).to_bytes(len(token) // 2, 'little'))
                if image[offset:offset + len(encoded)] != encoded:
                    raise ValueError(f'{listing.name}: encoded bytes differ at {offset:04X}h; '
                                     f'run make -B {build_target}')
        expanding = macro
    if not addresses or min(addresses) != 0:
        raise ValueError(f'{listing.name}: no complete COM/image address listing')
    return sorted(addresses | {image_length})


def validate_sys_image(name, image):
    """Without a historical SYS reference, verify the linked COM extraction."""
    executable = (ROOT / (name + '.exe')).read_bytes()
    if len(executable) < 28:
        raise ValueError(f'{name}.exe: missing MZ header')
    header = struct.unpack_from('<14H', executable)
    if (header[0] != 0x5A4D or header[3] != 0 or header[10:12] != (0x100, 0)):
        raise ValueError(f'{name}.exe: expected relocation-free COM intermediate')
    end = (header[2] - 1) * 512 + (header[1] or 512)
    if end > len(executable) or executable[header[4] * 16 + 0x100:end] != image:
        raise ValueError(f'{name}.com: differs from its linked executable image')


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
    name = ALIASES.get(name, name)
    reference = {'ibmfmt': 'format', 'msfmt': 'msformat',
                 'ibmboot': 'format', 'msboot': 'msformat',
                 'ibmedlin': 'edlin'}.get(name, name)
    extension = '.exe' if name == 'exe2bin' else '.com'
    reference_path = ROOT / 'reference' / (reference + extension)
    boot_only = name in ('ibmboot', 'msboot')
    built = ROOT / (name + ('.bin' if boot_only else extension))
    built_image = built.read_bytes()
    has_reference = reference_path.exists()
    if not has_reference and name not in SYS_VARIANTS:
        raise ValueError(f'{reference_path}: original reference is missing')
    image = reference_path.read_bytes() if has_reference else built_image
    if boot_only:
        image = image[0xBE8:0xDE8]
    if built_image != image:
        raise ValueError(f'{built.name}: rebuilt bytes differ from the reference')
    if not has_reference:
        validate_sys_image(name, image)
    target = ROOT / 'mappings' / f'{name}.tsv'
    old = read_records(target) if target.exists() else None
    if old is not None:
        validate_reference_records(old, image, name)
    if name == 'chkdsk' and old is not None:
        print(f'{name}: {len(image)} mapped bytes intact; rebuilt binary matches')
        return
    statements = list(source_statements(
        name + '.asm', msver=name in ('msfmt', 'msboot', 'msedlin', 'mssys'), boot_only=boot_only))
    origin = 0 if boot_only or name == 'exe2bin' else 0x100
    boundaries = listing_boundaries(name, statements, image, origin) if old is None else None
    instructions = iter(row for row in (old or []) if row['kind'] == 'code')
    cursor = 0
    rows = []
    for filename, lineno, statement, in_boot in statements:
        data = data_statement(statement) is not None
        if data:
            length = data_size(statement)
        elif boundaries is not None:
            position = bisect.bisect_left(boundaries, cursor)
            if position >= len(boundaries) - 1 or boundaries[position] != cursor:
                raise ValueError(f'{filename}:{lineno}: source does not align with MASM listing')
            length = boundaries[position + 1] - cursor
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
        if old is not None and target.read_text() != stream.getvalue():
            raise ValueError(f'{target.name}: stale; run tools/asm_byte_map.py {name}')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(stream.getvalue())
    if has_reference:
        print(f'{name}: {cursor} bytes mapped; source locations and original binary match')
    else:
        print(f'{name}: {cursor} bytes mapped; linked image/source verified; '
              f'no original reference ({reference_path.relative_to(ROOT)})')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='+', choices=['diskcopy', 'diskcomp', 'chkdsk',
        'mode', 'comp', 'filcom', 'debug', 'exe2bin', 'ibmfmt', 'msfmt', 'ibmboot', 'msboot',
        'msedlin', 'ibmedlin', 'mssys', 'ibmsys'], type=lambda name: ALIASES.get(name, name))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        for name in args.names:
            audit(name, args.check)
    except (OSError, ValueError, SyntaxError) as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()
