	TITLE	SCP 8086 Monitor 1.9 - DOS COM version

; DOS .COM wrapper for mon.asm
; Assembles as a standard PC-DOS COM file (INT 16h/INT 10h BIOS I/O).
; BOOTMON selects boot-only command bindings in monwrap.asm.

BOOTMON EQU 0		; B reboots through BIOS; Q returns to DOS.

CODE	SEGMENT
	ASSUME	CS:CODE, DS:CODE, SS:CODE, ES:CODE
	ORG	100H

_start:

	INCLUDE	MON.ASM

CODE	ENDS
	END	_start
