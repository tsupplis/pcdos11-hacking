	TITLE	MS-DOS version 1.25 by Tim Paterson     March 3, 1982
	PAGE	60,132

;Use the following booleans to set assembly flags
FALSE   EQU     0
TRUE    EQU     NOT FALSE

; Use the switches below to produce the standard Microsoft version of the IBM
; version of the operating system
MSVER	EQU	FALSE
IBMVER	EQU	TRUE

; Little extensions and patches
CMDEXT  EQU TRUE

; Set this switch to cause DOS to move itself to the end of memory
HIGHMEM	EQU	FALSE

	INCLUDE	COMMAND.ASM
