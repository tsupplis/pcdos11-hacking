#!/usr/bin/env python3
"""Compare original/reconstructed DEBUG behavior in a temporary emu2 workspace.

Port I/O and absolute disk writes are deliberately outside these test cases.
The opcode sweep disassembles bytes; it never executes the generated instructions.
"""
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def execute(directory, executable, script):
    result = subprocess.run(['emu2', executable], cwd=directory, input=script,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    if result.returncode:
        raise RuntimeError(f'{executable}: exit {result.returncode}: {result.stdout!r}')
    output_file = directory / 'out.bin'
    return result.stdout, output_file.read_bytes() if output_file.exists() else None


def main():
    # The synthetic EXE relocates the immediate operand of MOV AX,1234h.
    header = bytearray(512)
    for offset, value in [(0, 0x5A4D), (2, 16), (4, 2), (6, 1), (8, 32),
                          (12, 0xFFFF), (16, 0x100), (24, 28), (28, 1)]:
        struct.pack_into('<H', header, offset, value)
    exe_input = header + b'\xB8\x34\x12\xCD\x20' + bytes(11)
    sweep = b''.join(f'e 100 {opcode:02x} '.encode() + b'00 ' * 12 + b'\nu 100 l1\n'
                     for opcode in range(256)) + b'q\n'
    cases = [
        ('arithmetic', b'h 1234 1\nq\n', (b'1235  1233',)),
        ('memory', b'e 100 41 42 43 44\nd 100 l4\nf 110 l8 55 aa\n'
         b'm 110 l8 120\nc 110 l8 120\ns 110 l8 55 aa\nq\n',
         (b'41 42 43 44', b'ABCD', b':0110', b':0116')),
        ('overlapping_move', b'e 100 00 01 02 03 04 05 06 07\nm 100 l8 102\n'
         b'd 100 la\nq\n', (b'00 01 00 01 02 03 04 05', b'06 07')),
        ('compare_mismatch', b'e 100 41 42 43 44\ne 110 41 42 5a 44\n'
         b'c 100 l4 110\nq\n', (b':0102', b':0112', b'43', b'5A')),
        ('quoted_strings', b'e 100 "MiXeD"\nd 100 l5\nq\n', (b'MiXeD',)),
        ('register_edit', b'r ax\nbeef\nr\nq\n', (b'AX=BEEF',)),
        ('unassemble', b'e 100 b8 34 12 8b 46 fe 26 8b 07 83 c0 ff eb fe\n'
         b'u 100 10d\nq\n', (b'AX,1234', b'AX,[BP-02]', b'SEG\tES', b'AX,-01', b'JMPS\t010C')),
        ('breakpoint_trace', b'e 100 b8 34 12 40 cd 20\ng =100 103\nt\nq\n',
         (b'AX=1234', b'IP=0103', b'AX=1235', b'IP=0104')),
        ('binary_file_load', b'n input.bin\nl\nd 100 l4\nq\n', (b'WXYZ',)),
        ('binary_file_write', b'e 100 41 42 43 44\nn out.bin\nr bx\n0\nr cx\n4\nw\nq\n',
         (b'Writing 0004 bytes',)),
        ('exe_relocation_load', b'n input.exe\nl\nr\nq\n', (b'IP=0000', b'SP=0100')),
        # Preserve the original's reversed HEX dispatch rather than correcting it.
        ('hex_L_original_error', b'n input.hex\nl\nq\n', (b'EXE/HEX file cannot be written',)),
        ('hex_W_original_read', b'n input.hex\nw\nd 100 l4\nq\n', (b'ABCD',)),
        ('opcode_dispatch', sweep, (b'SEG\tES', b'INC\tW,[BX+SI]')),
    ]
    with tempfile.TemporaryDirectory(prefix='dos-debug-') as name:
        directory = Path(name)
        shutil.copyfile(ROOT / 'reference/debug.com', directory / 'old.com')
        shutil.copyfile(ROOT / 'debug.com', directory / 'new.com')
        for case, script, expected in cases:
            outputs = []
            for executable in ('old.com', 'new.com'):
                (directory / 'input.bin').write_bytes(b'WXYZ')
                (directory / 'input.exe').write_bytes(exe_input)
                (directory / 'input.hex').write_bytes(b':0401000041424344F1\r\n:00000001FF\r\n\x1a')
                (directory / 'out.bin').unlink(missing_ok=True)
                outputs.append(execute(directory, executable, script))
            if outputs[0] != outputs[1]:
                raise RuntimeError(f'DEBUG {case}: original/rebuilt output differs')
            console, output_file = outputs[1]
            for value in expected:
                if value not in console:
                    raise RuntimeError(f'DEBUG {case}: missing expected output {value!r}')
            if case == 'binary_file_write' and output_file != b'ABCD':
                raise RuntimeError('DEBUG: written binary differs from the entered bytes')
            if case == 'exe_relocation_load':
                segment = int(re.search(rb'CS=([0-9A-F]{4})', console)[1], 16)
                relocated_operand = f'AX,{(segment + 0x1234) & 0xFFFF:04X}'.encode()
                if relocated_operand not in console:
                    raise RuntimeError('DEBUG: EXE relocation did not adjust the immediate word')
            if case == 'opcode_dispatch' and console.count(b':0100 ') != 256:
                raise RuntimeError('DEBUG: opcode sweep did not reach all 256 entries')
    print(f'DEBUG: {len(cases)} original/rebuilt runtime cases matched; all 256 opcode entries decoded')


if __name__ == '__main__':
    main()
