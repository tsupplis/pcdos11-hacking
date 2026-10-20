#!/usr/bin/env python3
"""Compare a historical IBM COMMAND build with reference/command.com.

Build in a temporary directory with CMDEXT and HIGHMEM disabled. The configured
wrappers and normal extended COMMAND outputs are left untouched.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def historical_wrapper():
    source = (ROOT / 'ibmcmd.asm').read_text()
    for flag in ('CMDEXT', 'HIGHMEM'):
        pattern = rf'^([ \t]*{flag}[ \t]+EQU[ \t]+)(TRUE|FALSE)([ \t]*(?:;.*)?)$'
        source, count = re.subn(pattern, r'\g<1>FALSE\3', source, flags=re.I | re.M)
        if count != 1:
            raise ValueError(f'ibmcmd.asm: expected exactly one {flag} switch')
    return source.replace('\n', '\r\n').encode('ascii')


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
        (directory / 'ibmcmd.asm').write_bytes(historical_wrapper())
        shutil.copyfile(ROOT / 'command.asm', directory / 'command.asm')
        output = run(directory, 'msmasm.exe', 'ibmcmd,ibmcmd,ibmcmd,ibmcmd')
        summaries = re.findall(r'Errors\s+Errors\s+(\d+)\s+(\d+)', output)
        if summaries != [('0', '0')]:
            raise ValueError(f'MASM historical COMMAND build failed\n{output}')
        run(directory, 'link.exe', 'ibmcmd,ibmcmd,ibmcmd,ibmcmd,')
        run(directory, 'exe2bin.exe', 'ibmcmd.exe', 'ibmcmd.com')
        rebuilt = (directory / 'ibmcmd.com').read_bytes()
        if rebuilt != reference:
            offset = next((i for i, pair in enumerate(zip(rebuilt, reference))
                           if pair[0] != pair[1]), min(len(rebuilt), len(reference)))
            raise ValueError(f'COMMAND differs at file offset {offset:04X}h '
                             f'({len(rebuilt)} rebuilt / {len(reference)} reference bytes)')
    print(f'IBM COMMAND: {len(reference)} bytes match reference/command.com '
          '(CMDEXT=FALSE, HIGHMEM=FALSE; historical configuration)')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f'error: {error}')
