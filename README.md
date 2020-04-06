# PC-DOS 1.1 Hacking - Playing with command.com

## Sources

The experiment started from the vintage MS-DOS code opened by Microsoft:

https://github.com/microsoft/MS-DOS/blob/master/v1.25/source/COMMAND.ASM

## MIT License (In line with Source License):

- https://github.com/tsupplis/pcdos11-hacking/blob/master/LICENSE.md
- https://github.com/microsoft/MS-DOS/blob/master/LICENSE.md

## Configs

- msdosenh: slightly enhanced PC-DOS 1.1 command.com marked as 1.25A/1.17A
    - VER command
    - Addition of command.com search on A: after default drive search failed
- msdosorg: MS-DOS 1.25 command 1.17 vanilla command.com rebuilt
    - Addition of FCB Drive 0'ing from Zenith ZDOS before opening command.com
- pcdosenh: slightly enhanced PC-DOS 1.1 command.com marked as 1.10A
    - VER command
    - CLS command (BIOS)
- pcdosorg: PC-DOS 1.1 command.com rebuilt 
    - Checked against PC-DOS 1.1 distribution
    - SHA256(pcdosorg.com)= 84034261608f7b9d38a6b81b6896bb5cc45dc5ebfae0b0927081f86f354aa571

## TODO: Other little changes

- pcdosenh:
    - Search path on A: if default drive seach fails
    - Investigate further other MS-DOS 1.25 variations

## Build/Test Dependencies

### Linux/macOS

- pce emulator (test)
- emu2 (for build from macosx/linux)
- pc-dos 1.1 floppy image (for test if available)
- exe2bin.exe (any DOW will do)
- ibm assembler 2.0 or masm >= 3.0 or compatible (masm.exe link.exe)

### DOS

- exe2bin.exe
- IBM assembler 2.0 or Microsoft masm >= 3.0 (masm.exe,link.exe)

## Build

- Use Makefile on Linux, macOS
- Use Makefile.dos on Win32, DOS (builds only PC-DOS configs)

