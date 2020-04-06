# PC-DOS 1.1 hacking: playing with command.com

## configs

- msdosenh.asm: slightly enhanced pc-dos 1.1 command.com marked as 1.25A
    - VER command
- sdosorg.asm: pc-dos 1.1 command.com rebuilt
- pcdosenh.asm: slightly enhanced pc-dos 1.1 command.com marked as 1.10A
    - VER command
    - CLS command (BIOS)
- pcdosorg.asm: pc-dos 1.1 command.com rebuilt 
    - SHA256(pcdosorg.com)= 84034261608f7b9d38a6b81b6896bb5cc45dc5ebfae0b0927081f86f354aa571

## build/test dependencies

- pce emulator (test)
- emu2 (for build from macosx/linux)
- pc-dos 1.1 floppy image 
- exe2bin.exe
- ibm assembler 2.0 or masm >= 3.0 (masm.exe link.exe)

## build

```
$ emu2 masm.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,
Microsoft MACRO Assembler  Version 3.00               
(C)Copyright Microsoft Corp 1981, 1983, 1984


33684 Bytes free   

Warning Severe
Errors	Errors 
0	0
e emu2 link.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,

Microsoft 8086 Object Linker
Version 3.00 (C) Copyright Microsoft Corp 1983, 1984, 1985

Warning: no stack segment
$ emu2 exe2bin.exe pcdosenh.exe pcdosenh.com
```
