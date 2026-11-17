#!/usr/bin/env python3
"""Check the generated 320 KiB DOS 1.x templates and base-image boot layout."""
from pathlib import Path
import struct


def read(name):
    data = Path(name).read_bytes()
    assert len(data) == 327680, name
    assert data[512:1024] == data[1024:1536], name
    assert data[512:515] == b'\xff\xff\xff', name
    return data


empty = read('empty.img')
assert struct.unpack_from('<HBHBHHBHHH', empty, 11) == (
    512, 2, 1, 2, 112, 640, 255, 1, 8, 2)
assert empty[1536:5120] == bytes(3584)
assert empty[515:1024] == bytes(509)
print('PASS: empty.img geometry, empty root, FAT copies')

for flavor, boot, files in (
    ('pcdos', 'ibmboot.bin', [('IBMBIO  COM', 'ibmbio.com'),
                             ('IBMDOS  COM', 'ibmdos.com'),
                             ('COMMAND COM', 'ibmcmd.com')]),
    ('msdos', 'msboot.bin', [('IO      SYS', 'ibmbio.com'),
                             ('MSDOS   SYS', 'msdos.com'),
                             ('COMMAND COM', 'mscmd.com')]),
):
    sector = bytearray(Path(boot).read_bytes())
    assert len(sector) == 512
    sector[3:5] = b'\x03\x01'
    template = read(flavor + '.img')
    assert template[:512] == sector
    assert template[512:] == empty[512:]
    print(f'PASS: {flavor}.img patched boot sector, identical empty filesystem')

    data = read(flavor + '_base.img')
    assert data[:512] == sector
    fat = data[512:1024]
    next_cluster = 2
    for index, (name, source) in enumerate(files):
        entry = data[1536 + index * 32:1568 + index * 32]
        payload = Path(source).read_bytes()
        cluster, size = struct.unpack_from('<HI', entry, 26)
        assert entry[:11] == name.encode('ascii')
        assert entry[11] == (6 if index < 2 else 0)
        assert size == len(payload) and cluster == next_cluster
        result = bytearray()
        while True:
            offset = (10 + (cluster - 2) * 2) * 512
            result.extend(data[offset:offset + 1024])
            next_cluster = cluster + 1
            value = int.from_bytes(fat[cluster * 3 // 2:cluster * 3 // 2 + 2], 'little')
            value = (value >> 4 if cluster & 1 else value) & 0xfff
            if value >= 0xff8:
                break
            assert value == next_cluster, 'System files must be contiguous'
            cluster = value
        assert result[:size] == payload
    # The boot sector starts at LBA 10 and loads to physical 0600h.
    # IBMBIO expects its entry at 0060:0000 and DOS at 00E0:0000.
    loaded = data[10 * 512:30 * 512]
    bios = Path(files[0][1]).read_bytes()
    dos = Path(files[1][1]).read_bytes()
    assert loaded[:len(bios)] == bios
    assert loaded[0x800:0x800 + len(dos)] == dos
    print(f'PASS: {flavor}_base.img directory order, attributes, FAT chains, payloads, boot load window')
