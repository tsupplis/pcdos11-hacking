# PC-DOS 1.1 Hacking - Playing with command.com

## Sources

The experiment started from the vintage MS-DOS code opened by Microsoft:

https://github.com/microsoft/MS-DOS/blob/master/v1.25/source/COMMAND.ASM

## MIT License (In line with Source License):

- https://github.com/tsupplis/pcdos11-hacking/blob/master/LICENSE.md
- https://github.com/microsoft/MS-DOS/blob/master/LICENSE.md

## First Contact

There is a first failure on EQU symbol redefined. This prevents compilation.

```
156c156
< ZERO    EQU     $
---
> ZERO    =       $
```

To get to the official PC-DOS binary production:

A triple NOP replaces the MS instruction MOV [COMFCB],AL. This change fixes reload from command.com
on drive A: by not overriding the first FCB byte with 0 (Default drive).

```
469a474,479
>         IF IBMVER
>         NOP
>         NOP
>         NOP
>         ENDIF
>         IF MSVER
470a481
>         ENDIF
2166d2176
< 
```

The 2 previous changes allow recreation of the PC-DOS exact command.com, when MSVER is set to FALSE and
IBMVER is set to TRUE

A third small change has been added in MSVER mode, before opening the command.com file. To be checked if
this is really necessary ...

```
>         IF MSVER
>         MOV     AL, 0
>         MOV     [COMFCB], AL
>         ENDIF
```

Those variations beetween IBM and Microsoft seem to be linked to the command.com file being searched on
the default drive (Microsoft) or on drive A: (IBM).

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
    - https://github.com/microsoft/MS-DOS/blob/master/v1.25/bin/COMMAND.COM
    - SHA256(pcdosorg.com)= 84034261608f7b9d38a6b81b6896bb5cc45dc5ebfae0b0927081f86f354aa571

## TODO: Other little changes

- pcdosenh:
    - Search path on A: if default drive seach fails
    - Investigate further other MS-DOS 1.25 variations
- bios and dos

## Build/Test Dependencies

### Linux/macOS

- pce emulator (test)
- emu2 (for build from macosx/linux)
- pc-dos 1.1 floppy image (for test if available)
- exe2bin.exe from https://github.com/microsoft/MS-DOS/blob/master/v1.25/bin/EXE2BIN.EXE
- ibm link.exe 1.10 from https://github.com/microsoft/MS-DOS/blob/master/v1.25/bin/LINK.EXE
- microsoft masm.exe 1.10 (patched, cf below) https://github.com/microsoft/MS-DOS/blob/master/v2.0/bin/MASM.EXE

### DOS

- exe2bin.exe from https://github.com/microsoft/MS-DOS/blob/master/v1.25/bin/EXE2BIN.EXE
- ibm link.exe from https://github.com/microsoft/MS-DOS/blob/master/v1.25/bin/LINK.EXE
- microsoft masm.exe 1.10 (patched, cf below) https://github.com/microsoft/MS-DOS/blob/master/v2.0/bin/MASM.EXE

## Build

- Use Makefile on Linux, macOS
- Use Makefile.dos on Win32, DOS (builds only PC-DOS configs)

## MASM Fix

The 1.10 version of MASM part of the MS-DOS 2.00 distribution hangs on emulators, including dosbox and emu2. 

There is a detailed explanation at: https://slions.net/threads/debugging-ibm-macro-assembler-version-1-00.33/

The execution of the Faulty code looks like this:

```
11AD:0000 B83B0F           MOV     AX,0F3B
11AD:0003 8ED8             MOV     DS,AX
11AD:0005 8C062400         MOV     [0024],ES
11AD:0009 FA               CLI
11AD:000A 8ED0             MOV     SS,AX
11AD:000C 268B1E0200       MOV     BX,ES:[0002]
11AD:0011 2BD8             SUB     BX,AX
11AD:0013 81FB0010         CMP     BX,1000
11AD:0017 7E03             JLE     001C
```

The fix is just about changing the JLE into JBE (7E03 -> 7603)

```
11AD:0000 B83B0F           MOV     AX,0F3B
11AD:0003 8ED8             MOV     DS,AX
11AD:0005 8C062400         MOV     [0024],ES
11AD:0009 FA               CLI
11AD:000A 8ED0             MOV     SS,AX
11AD:000C 268B1E0200       MOV     BX,ES:[0002]
11AD:0011 2BD8             SUB     BX,AX
11AD:0013 81FB0010         CMP     BX,1000
11AD:0017 7603             JBE     001C
```

The masm binary checked in git is fixed.
