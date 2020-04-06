# PC-DOS 1.1 hacking: Playing with command.com

## Configs

- msdosenh: slightly enhanced PC-DOS 1.1 command.com marked as 1.25A/1.17A
    - VER command
    - Addition of command.com searchi on A: after default drive search failed
- msdosorg: MS-DOS 1.25 command 1.17 vanilla command.com rebuilt
    - Addition of FCB Drive 0'ing from Zenith ZDOS before opening command.com
- pcdosenh: slightly enhanced PC-DOS 1.1 command.com marked as 1.10A
    - VER command
    - CLS command (BIOS)
- pcdosorg: PC-DOS 1.1 command.com rebuilt 
    - checked against PC-DOS 1.1 distribution
    - SHA256(pcdosorg.com)= 84034261608f7b9d38a6b81b6896bb5cc45dc5ebfae0b0927081f86f354aa571

## TODO: Other little changes

- pcdosenh:
    - Search path on A: if default drive seach fails

## Build/Test Dependencies

### Linux/macOS

- pce emulator (test)
- emu2 (for build from macosx/linux)
- pc-dos 1.1 floppy image 
- exe2bin.exe
- ibm assembler 2.0 or masm >= 3.0 (masm.exe link.exe)

### DOS

- exe2bin.exe
- IBM assembler 2.0 or Microsoft masm >= 3.0 (masm.exe,link.exe)

## Build

- Use Makefile on Linux, macOS
- Use Makefile.dos on Win32, DOS (builds only PC-DOS configs)

```
$ make -f Makefile pcdosenh.com
emu2 masm.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,
Microsoft MACRO Assembler  Version 3.00               
(C)Copyright Microsoft Corp 1981, 1983, 1984


33684 Bytes free   

Warning Severe
Errors	Errors 
0	0
emu2 link.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,

Microsoft 8086 Object Linker
Version 3.00 (C) Copyright Microsoft Corp 1983, 1984, 1985

Warning: no stack segment
emu2 exe2bin.exe pcdosenh.exe pcdosenh.com
```
