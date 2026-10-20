#!/usr/bin/env python3
"""Compare original and reconstructed DOS utility behavior using emu2."""
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(directory, executable, args, input_bytes=b''):
    result = subprocess.run(['emu2', executable, *args], cwd=directory,
                            input=input_bytes, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=10)
    if result.returncode:
        raise RuntimeError(f'{executable}: exit {result.returncode}: {result.stdout!r}')
    return result.stdout


def check_filcom(directory):
    lines = [f'line {i:02d}\r\n'.encode() for i in range(12)]
    text = b''.join(lines) + b'\x1a'
    changed = b''.join(lines[:4] + [b'CHANGED\r\n'] + lines[5:]) + b'\x1a'
    inserted = b''.join(lines[:4] + [b'inserted\r\n'] + lines[4:]) + b'\x1a'
    cases = [
        ('binary_equal', b'alpha\r\nbeta\r\n\x1a', b'alpha\r\nbeta\r\n\x1a', ['/B']),
        ('binary_difference', b'alpha\r\nbeta\r\n\x1a', b'alpha\r\nzeta\r\n\x1a', ['/B']),
        ('binary_length', b'abc', b'abcdef', ['/B']),
        ('text_equal', text, text, ['/A']),
        ('text_resynchronize', text, changed, ['/A']),
        ('text_case_changes_with_C', text, text.upper(), ['/A', '/C']),
        ('text_insertion', text, inserted, ['/A']),
        ('comments_default', b'alpha; old comment\r\nbeta\r\n\x1a',
         b'alpha; new comment\r\nbeta\r\n\x1a', ['/A']),
        ('comments_C', b'alpha; old comment\r\nbeta\r\n\x1a',
         b'alpha; new comment\r\nbeta\r\n\x1a', ['/A', '/C']),
    ]
    for name, first, second, switches in cases:
        (directory / 'first.txt').write_bytes(first)
        (directory / 'second.txt').write_bytes(second)
        outputs = []
        for executable in ('oldfc.com', 'newfc.com'):
            output = run(directory, executable,
                         ['first.txt,second.txt,out.dif', *switches])
            outputs.append((output, (directory / 'out.dif').read_bytes()))
        if outputs[0] != outputs[1]:
            raise RuntimeError(f'FILCOM {name}: original and reconstructed outputs differ')
        text_output = outputs[1][1].split(b'\x1a')[0]
        if name == 'binary_difference':
            assert all(value in text_output for value in (b'000007', b'62', b'7A'))
        elif name == 'binary_length':
            assert b'LARGER' in text_output
        elif name in ('text_equal', 'comments_default'):
            assert b'different' not in text_output.lower() and b'old comment' not in text_output
        elif name == 'text_resynchronize':
            assert b'CHANGED' in text_output
        elif name == 'text_insertion':
            assert b'inserted' in text_output
        elif name == 'comments_C':
            assert b'old comment' in text_output and b'new comment' in text_output
    return len(cases)


def check_exe2bin(directory):
    # IP=0100h strips the COM prefix; IP=0000h retains the whole segment.
    for source, expected in [('comtest.exe', (ROOT / 'reference/filcom.com').read_bytes()),
                             ('exbimage.exe', (ROOT / 'reference/exe2bin.exe').read_bytes())]:
        results = []
        for executable, output in [('oldex.exe', 'old.bin'), ('newex.exe', 'new.bin')]:
            console = run(directory, executable, [source, output])
            results.append((console, (directory / output).read_bytes()))
        if results[0] != results[1] or results[1][1] != expected:
            raise RuntimeError(f'EXE2BIN {source}: conversion mismatch')
    # A minimal MZ input with one relocation exercises the interactive fixup path.
    header = bytearray(512)
    for offset, value in [(0, 0x5A4D), (2, 16), (4, 2), (6, 1), (8, 32), (24, 28)]:
        struct.pack_into('<H', header, offset, value)
    (directory / 'fixup.exe').write_bytes(header + b'\x34\x12' + bytes(14))
    results = []
    for executable, output in [('oldex.exe', 'old.bin'), ('newex.exe', 'new.bin')]:
        console = run(directory, executable, ['fixup.exe', output], b'0010\r\n')
        results.append((console, (directory / output).read_bytes()))
    if results[0] != results[1] or results[1][1] != b'\x44\x12' + bytes(14):
        raise RuntimeError('EXE2BIN: relocation base was not applied as expected')
    return 3


def main():
    with tempfile.TemporaryDirectory(prefix='dos-utility-') as name:
        directory = Path(name)
        for source, target in [('reference/filcom.com', 'oldfc.com'), ('filcom.com', 'newfc.com'),
                               ('reference/exe2bin.exe', 'oldex.exe'), ('exe2bin.exe', 'newex.exe'),
                               ('filcom.exe', 'comtest.exe'), ('exbimage.exe', 'exbimage.exe')]:
            shutil.copyfile(ROOT / source, directory / target)
        counts = {'filcom': check_filcom(directory), 'exe2bin': check_exe2bin(directory)}
        print('DOS runtime comparisons matched original outputs: ' + json.dumps(counts))


if __name__ == '__main__':
    main()
