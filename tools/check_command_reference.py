#!/usr/bin/env python3
"""Compare a historical IBM COMMAND build with reference/command.com.

Build origcmd.asm unchanged in a temporary directory. This configuration selects
the historical IBM COMMAND; normal extended COMMAND outputs are left untouched.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(directory, executable, *arguments):
    result = subprocess.run(['emu2', str(ROOT / 'bin' / executable), *arguments],
                            cwd=directory, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=30)
    output = result.stdout.decode('ascii', errors='replace')
    if result.returncode:
        raise ValueError(f'{executable}: exit {result.returncode}\n{output}')
    return output


def main():
    reference = (ROOT / 'reference/command.com').read_bytes()
    with tempfile.TemporaryDirectory(prefix='command-reference-') as name:
        directory = Path(name)
        shutil.copyfile(ROOT / 'origcmd.asm', directory / 'origcmd.asm')
        shutil.copyfile(ROOT / 'command.asm', directory / 'command.asm')
        output = run(directory, 'msmasm.exe', 'origcmd,origcmd,origcmd,origcmd')
        summaries = re.findall(r'Errors\s+Errors\s+(\d+)\s+(\d+)', output)
        if summaries != [('0', '0')]:
            raise ValueError(f'MASM historical COMMAND build failed\n{output}')
        run(directory, 'link.exe', 'origcmd,origcmd,origcmd,origcmd,')
        run(directory, 'exe2bin.exe', 'origcmd.exe', 'origcmd.com')
        rebuilt = (directory / 'origcmd.com').read_bytes()
        if rebuilt != reference:
            offset = next((i for i, pair in enumerate(zip(rebuilt, reference))
                           if pair[0] != pair[1]), min(len(rebuilt), len(reference)))
            raise ValueError(f'COMMAND differs at file offset {offset:04X}h '
                             f'({len(rebuilt)} rebuilt / {len(reference)} reference bytes)')
    print(f'IBM COMMAND: {len(reference)} bytes match reference/command.com '
          '(origcmd.asm configuration)')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f'error: {error}')
