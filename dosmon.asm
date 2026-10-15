	TITLE	SCP 8086 Monitor 1.9 - DOS COM version

; DOS .COM wrapper for mon.asm
; Assembles as a standard PC-DOS COM file (INT 16h/INT 10h BIOS I/O).
; Future: bootmon.asm will wrap the same mon.asm for boot-sector use.

CODE	SEGMENT
	ASSUME	CS:CODE, DS:CODE, SS:CODE, ES:CODE
	ORG	100H

_start:

	INCLUDE	MON.ASM

CODE	ENDS
	END	_start
