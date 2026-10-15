; Seattle Computer Products 8086 Monitor version 1.9  4-02-83
; Adapted for MASM / PC-DOS COM file
;   Original by Tim Paterson, Seattle Computer Products
; Copyright 1982,83 by Seattle Computer Products, Inc.

;System Equates

BUFLEN		EQU	80		;Maximum length of line input buffer
BPMAX		EQU	10		;Maximum number of breakpoints
BPLEN		EQU	2*BPMAX		;Length of breakpoint table
REGTABLEN	EQU	14		;Number of registers
PROMPT		EQU	'>'
CAN		EQU	'@'

;RAM area.

BRKCNT:	DW	?		;Number of breakpoints
TCOUNT:	DW	?		;Number of steps to trace
BPTAB:	DB	BPLEN DUP (?)		;Breakpoint table
LINEBUF:DB	BUFLEN+1 DUP (?)	;Line input buffer
	EVEN
	DB	50 DUP (?)		;Working stack area
STACK:

;Register save area

AXSAVE:	DW	?
BXSAVE:	DW	?
CXSAVE:	DW	?
DXSAVE:	DW	?
SPSAVE:	DW	?
BPSAVE:	DW	?
SISAVE:	DW	?
DISAVE:	DW	?
DSSAVE:	DW	?
ESSAVE:	DW	?
RSTACK:		;Stack set here so registers can be saved by pushing
SSSAVE:	DW	?
CSSAVE:	DW	?
IPSAVE:	DW	?
FSAVE:	DW	?
REGSIZ		EQU	$-AXSAVE

; Saved IVT vectors (for restoration on quit)
OLDINT1:	DW	?,?		;Original INT 1 vector (IP, CS)
OLDINT3:	DW	?,?		;Original INT 3 vector (IP, CS)
OLDINT1B:	DW	?,?		;Original INT 1Bh vector (IP, CS)

;Start of Monitor code

START:
;Save original INT 1 (single-step), INT 3 (breakpoint), INT 1Bh (Ctrl-Break) vectors
	XOR	AX,AX
	MOV	DS,AX			;DS=0 to address IVT
	MOV	AX,[4]
	MOV	[OLDINT1],AX		;Save INT 1 IP
	MOV	AX,[6]
	MOV	[OLDINT1+2],AX		;Save INT 1 CS
	MOV	AX,[0CH]
	MOV	[OLDINT3],AX		;Save INT 3 IP
	MOV	AX,[0EH]
	MOV	[OLDINT3+2],AX		;Save INT 3 CS
	MOV	AX,[6CH]
	MOV	[OLDINT1B],AX		;Save INT 1Bh IP
	MOV	AX,[6EH]
	MOV	[OLDINT1B+2],AX		;Save INT 1Bh CS
;Restore segment registers to COM segment
	PUSH	CS
	POP	DS
	PUSH	CS
	POP	ES
;Initialise user register save area to zero, set flags to enable interrupts
	MOV	DI,OFFSET AXSAVE
	MOV	CX,REGSIZ/2-1
	XOR	AX,AX
	REP	STOSW
	MOV	AX,0200H		;Flags: IF=1 (interrupts enabled)
	STOSW
	MOV	BYTE PTR [SPSAVE+1],16	;Set user SP to 1000H
;Reset stack to our own
	MOV	SP,OFFSET STACK

DOMON:
	MOV	SI,OFFSET HEADER
	CALL	PRINTMES
COMMAND:
;Re-establish initial conditions
	CLD
	PUSH	CS
	POP	DS
	PUSH	CS
	POP	ES
	MOV	SP,OFFSET STACK
	MOV	AL,PROMPT
	CALL	CONOUT
	CALL	INBUF		;Get command line
;From now and throughout command line processing, DI points
;to next character in command line to be processed.
	CALL	SCANB		;Scan off leading blanks
	JZ	COMMAND		;Null command?
	MOV	AL,[DI]		;AL=first non-blank character
	CMP	AL,"?"		;Help command?
	JNZ	NHELP
	JMP	HELP
NHELP:
	AND	AL,0DFH		;Convert lower case
;Prepare command letter for table lookup
	SUB	AL,"B"		;Low end range check
	JC	ERR1
	CMP	AL,"T"+1-"B"	;Upper end range check
	JNC	ERR1
	INC	DI
	SHL	AL,1		;Times two
	CBW			;Now a 16-bit quantity
	XCHG	BX,AX		;In BX we can address with it
	CALL	WORD PTR [BX+COMTAB]	;Execute command
	JMP	SHORT COMMAND		;Get next command
ERR1:	JMP	ERROR

;Get input line

INBUF:
	MOV	DI,OFFSET LINEBUF	;Next empty buffer location
	XOR	CX,CX		;Character count
GETCH:
	CALL	CONIN		;Get input character
	CMP	AL,20H		;Check for control characters
	JC	CONTROL
	CMP	AL,7FH		;RUBOUT is a backspace
	JZ	BACKSP
	CALL	CONOUT		;Echo character
	CMP	AL,CAN		;Cancel line?
	JZ	KILL
	STOSB			;Put in input buffer
	INC	CX		;Bump character count
	CMP	CX,BUFLEN	;Buffer full?
	JBE	GETCH		;Drop in to backspace if full
BACKSP:
	JCXZ	GETCH		;Can't backspace over nothing
	DEC	DI		;Drop pointer
	DEC	CX		;and character count
	CALL	BACKUP		;Send physical backspace
	JMP	SHORT GETCH		;Get next char.
CONTROL:
	CMP	AL,8		;Check for backspace
	JZ	BACKSP
	CMP	AL,13		;Check for carriage return
	JNZ	GETCH		;Ignore all other control char.
	STOSB			;Put the car. ret. in buffer
	MOV	DI,OFFSET LINEBUF	;Set up DI for command processing

;Output CR/LF sequence

CRLF:
	MOV	AL,13
	CALL	CONOUT
	MOV	AL,10
	JMP	SHORT CONOUT

;Cancel input line

KILL:
	CALL	CRLF
	JMP	COMMAND

;Character input routine — BIOS keyboard read

CONIN:
	MOV	AH,0
	INT	16H		;BIOS: wait for keypress, ASCII in AL
	AND	AL,7FH		;Only 7 bits
	RET

;Physical backspace - blank, backspace, blank

BACKUP:
	MOV	SI,OFFSET BACMES

;Print ASCII message. Last char has bit 7 set.
;Save byte in AH, mask AL for printing, test high bit after call.

PRINTMES:
	LODSB			;Get char to print
	MOV	AH,AL		;Keep copy for termination test
	AND	AL,7FH		;Mask off high bit before printing
	CALL	CONOUT
	SHL	AH,1		;Shift high bit of original into carry
	JNC	PRINTMES	;Not set — keep going
	RET

;Scan for parameters of a command

SCANP:
	CALL	SCANB		;Get first non-blank
	CMP	BYTE PTR [DI],","	;One comma between params OK
	JNE	EOLCHK		;If not comma, we found param
	INC	DI		;Skip over comma

;Scan command line for next non-blank character

SCANB:
	MOV	AL," "
	PUSH	CX		;Don't disturb CX
	MOV	CL,-1		;but scan as many as necessary
	REPE	SCASB
	DEC	DI		;Back up to first non-blank
	POP	CX
EOLCHK:
	CMP	BYTE PTR [DI],13
	RET

;Print the 5-digit hex address of SI and DS

OUTSI:
	MOV	DX,DS		;Put DS where we can work with it
	MOV	AH,0		;Will become high bits of DS
	CALL	SHIFT4		;Shift DS four bits
	ADD	DX,SI		;Compute absolute address
	JMP	SHORT OUTADD		;Finish below

;Print 5-digit hex address of DI and ES
;Same as OUTSI above

OUTDI:
	MOV	DX,ES
	MOV	AH,0
	CALL	SHIFT4
	ADD	DX,DI
;Finish OUTSI here too
OUTADD:
	ADC	AH,0		;Add in carry to high bits
	CALL	HIDIG		;Output hex value in AH

;Print out 16-bit value in DX in hex

OUT16:
	MOV	AL,DH		;High-order byte first
	CALL	HEX
	MOV	AL,DL		;Then low-order byte

;Output byte in AL as two hex digits

HEX:
	MOV	AH,AL		;Save for second digit
;Shift high digit into low 4 bits
	PUSH	CX
	MOV	CL,4
	SHR	AL,CL
	POP	CX

	CALL	DIGIT		;Output first digit
HIDIG:
	MOV	AL,AH		;Now do digit saved in AH
DIGIT:
	AND	AL,0FH		;Mask to 4 bits
;Trick 6-byte hex conversion works on 8086 too.
	ADD	AL,90H
	DAA
	ADC	AL,40H
	DAA

;Console output of character in AL — BIOS teletype

CONOUT:
	PUSH	AX
	PUSH	BX
	MOV	AH,0EH		;BIOS teletype output
	MOV	BH,0		;Page 0
	MOV	BL,07H		;Attribute (light grey on black)
	INT	10H
	POP	BX
	POP	AX
	RET

;Output one space

BLANK:
	MOV	AL," "
	JMP	SHORT CONOUT

;Output the number of blanks in CX

TAB:
	CALL	BLANK
	LOOP	TAB
	RET

;Command Table. Command letter indexes into table to get
;address of command. PERR prints error for no such command.

COMTAB:
	DW	BOOT		;B - reboot (INT 19h)
	DW	PERR		;C
	DW	DUMP		;D
	DW	ENTER		;E
	DW	FILL		;F
	DW	GO		;G
	DW	PERR		;H
	DW	INPUT		;I
	DW	PERR		;J
	DW	PERR		;K
	DW	PERR		;L
	DW	MOVE		;M
	DW	PERR		;N
	DW	OUTPUT		;O
	DW	PERR		;P
	DW	QUIT		;Q - quit to DOS
	DW	REG		;R
	DW	SEARCH		;S
	DW	TRACE		;T

;Given 20-bit address in AH:DX, breaks it down to a segment
;number in AX and a displacement in DX. Displacement is
;always zero except for least significant 4 bits.

GETSEG:
	MOV	AL,DL
	AND	AL,0FH		;AL has least significant 4 bits
	CALL	SHIFT4		;4-bit left shift of AH:DX
	MOV	DL,AL		;Restore lowest 4 bits
	MOV	AL,DH		;Low byte of segment number
	XOR	DH,DH		;Zero high byte of displacement
	RET

;Shift AH:DX left 4 bits

SHIFT4:
	SHL	DX,1
	RCL	AH,1	;1
	SHL	DX,1
	RCL	AH,1	;2
	SHL	DX,1
	RCL	AH,1	;3
	SHL	DX,1
	RCL	AH,1	;4
RET2:	RET

;RANGE - Looks for parameters defining an address range.
;The first parameter is a hex number of 5 or less digits
;which specifies the starting address. The second parameter
;may specify the ending address, or it may be preceded by
;"L" and specify a length (4 digits max), or it may be
;omitted and a length of 128 bytes is assumed. Returns with
;segment no. in AX and displacement (0-F) in DX.

RANGE:
	MOV	CX,5		;5 digits max
	CALL	GETHEX		;Get hex number
	PUSH	AX		;Save high 4 bits
	PUSH	DX		;Save low 16 bits
	CALL	SCANP		;Get to next parameter
	CMP	BYTE PTR [DI],"L"	;Length indicator?
	JE	GETLEN
	CMP	BYTE PTR [DI],"l"
	JE	GETLEN
	MOV	DX,128		;Default length
	CALL	HEXIN		;Second parameter present?
	JC	RNGRET		;If not, use default
	MOV	CX,5		;5 hex digits
	CALL	GETHEX		;Get ending address
	MOV	CX,DX		;Low 16 bits of ending addr.
	POP	DX		;Low 16 bits of starting addr.
	POP	BX		;BH=hi 4 bits of start addr.
	SUB	CX,DX		;Compute range
	SBB	AH,BH		;Finish 20-bit subtract
	JNZ	RNGERR		;Range must be less than 64K
	XCHG	AX,BX		;AH=starting, BH=ending hi 4 bits
	INC	CX		;Range must include ending location
	JMP	SHORT RNGCHK		;Finish range testing and return
GETLEN:
	INC	DI		;Skip over "L" to length
	MOV	CX,4		;Length may have 4 digits
	CALL	GETHEX		;Get the range
RNGRET:
	MOV	CX,DX		;Length
	POP	DX		;Low 16 bits of starting addr.
	POP	AX		;AH=hi 4 bits of starting addr.

;RNGCHK verifies that the range lies entirely within one segment.
;CX=0 means count=10000H. Range is within one segment only if
;adding the low 4 bits of the starting address to the count is
;<=10000H, because segments can start only on 16-byte boundaries.

RNGCHK:
	MOV	BX,DX		;Low 16 bits of start addr.
	AND	BX,0FH		;Low 4 bits of starting addr.
	JCXZ	MAXRNG		;If count=10000H then BX must be 0
	ADD	BX,CX		;Must be <=10000H
	JNC	GETSEG		;OK if strictly <
MAXRNG:
;If here because of JCXZ MAXRNG, we are testing if low 4 bits
;(in BX) are zero. If we dropped straight in, we are testing
;for BX+CX=10000H (=0). Either way, zero flag set means 
;withing range.
	JZ	GETSEG
RNGERR:
	MOV	AX,4700H+"R"	;RG ERROR
	JMP	ERR

;Dump an area of memory in both hex and ASCII

DUMP:
	CALL	RANGE		;Get range to dump
	PUSH	AX		;Save segment
	CALL	GETEOL		;Check for errors
	POP	DS		;Set segment
	MOV	SI,DX		;SI has displacement in segment
ROW:
	CALL	OUTSI		;Print address at start of line
	PUSH	SI		;Save address for ASCII dump
DUMP_BYTE:
	CALL	BLANK		;Space between bytes
DUMP_BYTE1:
	LODSB			;Get byte to dump
	CALL	HEX		;and display it
	POP	DX		;DX has start addr. for ASCII dump
	DEC	CX		;Drop loop count
	JZ	ASCII		;If through do ASCII dump
	MOV	AX,SI
	TEST	AL,0FH		;On 16-byte boundary?
	JZ	ENDROW
	PUSH	DX		;Didn't need ASCII addr. yet
	TEST	AL,7		;On 8-byte boundary?
	JNZ	DUMP_BYTE
	MOV	AL,"-"		;Mark every 8 bytes
	CALL	CONOUT
	JMP	SHORT DUMP_BYTE1
ENDROW:
	CALL	ASCII		;Show it in ASCII
	JMP	SHORT ROW		;Loop until count is zero
ASCII:
	PUSH	CX		;Save byte count
	MOV	AX,SI		;Current dump address
	MOV	SI,DX		;ASCII dump address
	SUB	AX,DX		;AX=length of ASCII dump
;Compute tab length. ASCII dump always appears on right side
;screen regardless of how many bytes were dumped. Figure 3
;characters for each byte dumped and subtract from 51, which
;allows a minimum of 3 blanks after the last byte dumped.
	MOV	BX,AX
	SHL	AX,1		;Length times 2
	ADD	AX,BX		;Length times 3
	MOV	CX,51
	SUB	CX,AX		;Amount to tab in CX
	CALL	TAB
	MOV	CX,BX		;ASCII dump length back in CX
ASCDMP:
	LODSB			;Get ASCII byte to dump
	AND	AL,7FH		;ASCII uses 7 bits
	CMP	AL,7FH		;Don't try to print RUBOUT
	JZ	NOPRT
	CMP	AL," "		;Check for control characters
	JNC	PRIN
NOPRT:
	MOV	AL,"."		;If unprintable character
PRIN:
	CALL	CONOUT		;Print ASCII character
	LOOP	ASCDMP		;CX times
	POP	CX		;Restore overall dump length
	JMP	CRLF		;Print CR/LF and return

;Block move one area of memory to another. Overlapping moves
;are performed correctly, i.e., so that a source byte is not
;overwritten until after it has been moved.

MOVE:
	CALL	RANGE		;Get range of source area
	PUSH	CX		;Save length
	PUSH	AX		;Save segment
	MOV	SI,DX		;Set source displacement
	MOV	CX,5		;Allow 5 digits
	CALL	GETHEX		;in destination address
	CALL	GETEOL		;Check for errors
	CALL	GETSEG		;Convert dest. to seg/disp
	MOV	DI,DX		;Set dest. displacement
	POP	BX		;Source segment
	MOV	DS,BX
	MOV	ES,AX		;Destination segment
	POP	CX		;Length
	CMP	DI,SI		;Check direction of move
	SBB	AX,BX		;Extend the CMP to 32 bits
	JB	COPYLIST	;Move forward into lower mem.
;Otherwise, move backward. Figure end of source and destination
;areas and flip direction flag.
	DEC	CX
	ADD	SI,CX		;End of source area
	ADD	DI,CX		;End of destination area
	STD			;Reverse direction
	INC	CX
COPYLIST:
	MOVSB	;Do at least 1 - Range is 1-10000H not 0-FFFFH
	DEC	CX
	REP	MOVSB			;Block move
	RET

;Fill an area of memory with a list values. If the list
;is bigger than the area, don't use the whole list. If the
;list is smaller, repeat it as many times as necessary.

FILL:
	CALL	RANGE		;Get range to fill
	PUSH	CX		;Save length
	PUSH	AX		;Save segment number
	PUSH	DX		;Save displacement
	CALL	LIST		;Get list of values to fill with
	POP	DI		;Displacement in segment
	POP	ES		;Segment
	POP	CX		;Length
	CMP	BX,CX		;BX is length of fill list
	MOV	SI,OFFSET LINEBUF	;List is in line buffer
	JCXZ	BIGRNG
	JAE	COPYLIST	;If list is big, copy part of it
BIGRNG:
	SUB	CX,BX		;How much bigger is area than list?
	XCHG	CX,BX		;CX=length of list
	PUSH	DI		;Save starting addr. of area
	REP	MOVSB			;Move list into area
	POP	SI
;The list has been copied into the beginning of the 
;specified area of memory. SI is the first address
;of that area, DI is the end of the copy of the list
;plus one, which is where the list will begin to repeat.
;All we need to do now is copy [SI] to [DI] until the
;end of the memory area is reached. This will cause the
;list to repeat as many times as necessary.
	MOV	CX,BX		;Length of area minus list
	PUSH	ES		;Different index register
	POP	DS		;requires different segment reg.
	JMP	SHORT COPYLIST	;Do the block move

;Search a specified area of memory for given list of bytes.
;Print address of first byte of each match.

SEARCH:
	CALL	RANGE		;Get area to be searched
	PUSH	CX		;Save count
	PUSH	AX		;Save segment number
	PUSH	DX		;Save displacement
	CALL	LIST		;Get search list
	DEC	BX		;No. of bytes in list-1
	POP	DI		;Displacement within segment
	POP	ES		;Segment
	POP	CX		;Length to be searched
	SUB	CX,BX		;  minus length of list
SCAN:
	MOV	SI,OFFSET LINEBUF	;List kept in line buffer
	LODSB			;Bring first byte into AL
DOSCAN:
	SCASB			;Search for first byte
	LOOPNE	DOSCAN		;Do at least once by using LOOP
	JNZ	HEXRET		;Exit if not found
	PUSH	BX		;Length of list minus 1
	XCHG	BX,CX
	PUSH	DI		;Will resume search here
	REPE	CMPSB			;Compare rest of string
	MOV	CX,BX		;Area length back in CX
	POP	DI		;Next search location
	POP	BX		;Restore list length
	JNZ	TEST		;Continue search if no match
	DEC	DI		;Match address
	CALL	OUTDI		;Print it
	INC	DI		;Restore search address
	CALL	CRLF
TEST:
	JCXZ	HEXRET
	JMP	SHORT SCAN		;Look for next occurrence

;Get the next parameter, which must be a hex number.
;CX is maximum number of digits the number may have.

GETHEX:
	CALL	SCANP		;Scan to next parameter
GETHEX1:
	XOR	DX,DX		;Initialize the number
	MOV	AH,DH
	CALL	HEXIN		;Get a hex digit
	JC	ERROR		;Must be one valid digit
	MOV	DL,AL		;First 4 bits in position
GETLP:
	INC	DI		;Next char in buffer
	DEC	CX		;Digit count
	CALL	HEXIN		;Get another hex digit?
	JC	HEXRET		;All done if no more digits
	JCXZ	ERROR		;Too many digits?
	CALL	SHIFT4		;Multiply by 16
	OR	DL,AL		;and combine new digit
	JMP	SHORT GETLP		;Get more digits

;Check if next character in the input buffer is a hex digit
;and convert it to binary if it is. Carry set if not.

HEXIN:
	MOV	AL,[DI]
	CMP	AL,'A'
	JB	HEXCHK
	AND	AL,0DFH		;Convert lower case

;Check if AL has a hex digit and convert it to binary if it
;is. Carry set if not.

HEXCHK:
	SUB	AL,"0"		;Kill ASCII numeric bias
	JC	HEXRET
	CMP	AL,10
	CMC
	JNC	HEXRET		;OK if 0-9
	AND	AL,0DFH		;Convert lower case
	SUB	AL,7		;Kill A-F bias
	CMP	AL,10
	JC	HEXRET
	CMP	AL,16
	CMC
HEXRET:	RET

;Process one parameter when a list of bytes is
;required. Carry set if parameter bad. Called by LIST

LISTITEM:
	CALL	SCANP		;Scan to parameter
	CALL	HEXIN		;Is it in hex?
	JC	STRINGCHK	;If not, could be a string
	MOV	CX,2		;Only 2 hex digits for bytes
	CALL	GETHEX		;Get the byte value
	MOV	[BX],DL		;Add to list
	INC	BX
GRET:	CLC			;Parameter was OK
	RET
STRINGCHK:
	MOV	AL,[DI]		;Get first character of param
	CMP	AL,"'"		;String?
	JZ	STRING
	CMP	AL,'"'		;Either quote is all right
	JZ	STRING
	STC			;Not string, not hex - bad
	RET
STRING:
	MOV	AH,AL		;Save for closing quote
	INC	DI
STRNGLP:
	MOV	AL,[DI]		;Next char of string
	INC	DI
	CMP	AL,13		;Check for end of line
	JZ	ERROR		;Must find a close quote
	CMP	AL,AH		;Check for close quote
	JNZ	STOSTRG		;Add new character to list
	CMP	AH,[DI]		;Two quotes in a row?
	JNZ	GRET		;If not, we're done
	INC	DI		;Yes - skip second one
STOSTRG:
	MOV	[BX],AL		;Put new char in list
	INC	BX
	JMP	SHORT STRNGLP		;Get more characters

;Get a byte list for ENTER, FILL or SEARCH. Accepts any number
;of 2-digit hex values or character strings in either single
;(') or double (") quotes.

LIST:
	MOV	BX,OFFSET LINEBUF	;Put byte list in the line buffer
LISTLP:
	CALL	LISTITEM	;Process a parameter
	JNC	LISTLP		;If OK, try for more
	SUB	BX,OFFSET LINEBUF	;BX now has no. of bytes in list
	JZ	ERROR		;List must not be empty

;Make sure there is nothing more on the line except for
;blanks and carriage return. If there is, it is an
;unrecognized parameter and an error.

GETEOL:
	CALL	SCANB		;Skip blanks
	JNZ	ERROR		;Better be a RETURN
	RET

;Command error. DI has been incremented beyond the
;command letter so it must decremented for the
;error pointer to work.

PERR:
	DEC	DI

;Syntax error. DI points to character in the input buffer
;which caused error. By subtracting from start of buffer,
;we will know how far to tab over to appear directly below
;it on the terminal. Then print "^ Error".

ERROR:
	SUB	DI,OFFSET LINEBUF-1	;How many char processed so far?
	MOV	CX,DI		;Parameter for TAB in CX
	CALL	TAB		;Directly below bad char
	MOV	SI,OFFSET SYNERR	;Error message

;Print error message and abort to command level

PRINT:
	CALL	PRINTMES
	JMP	COMMAND

;Short form of ENTER command. A list of values from the
;command line are put into memory without using normal
;ENTER mode.

GETLIST:
	CALL	LIST		;Get the bytes to enter
	POP	DI		;Displacement within segment
	POP	ES		;Segment to enter into
	MOV	SI,OFFSET LINEBUF	;List of bytes is in line buffer
	MOV	CX,BX		;Count of bytes
	REP	MOVSB			;Enter that byte list
	RET

;Enter values into memory at a specified address. If the
;line contains nothing but the address we go into "enter
;mode", where the address and its current value are printed
;and the user may change it if desired. To change, type in
;new value in hex. Backspace works to correct errors. If
;an illegal hex digit or too many digits are typed, the
;bell is sounded but it is otherwise ignored. To go to the
;next byte (with or without change), hit space bar. To
;back up to a previous address, type "-". On
;every 8-byte boundary a new line is started and the address
;is printed. To terminate command, type carriage return.
;   Alternatively, the list of bytes to be entered may be
;included on the original command line immediately following
;the address. This is in regular LIST format so any number
;of hex values or strings in quotes may be entered.

ENTER:
	MOV	CX,5		;5 digits in address
	CALL	GETHEX		;Get ENTER address
	CALL	GETSEG		;Convert to seg/disp format
;Adjust segment and displacement so we are in the middle
;of the segment instead of the very bottom. This allows
;backing up a long way.
	SUB	AH,8		;Adjust segment 32K down
	ADD	DH,80H		; and displacement 32K up
	PUSH	AX		;Save for later
	PUSH	DX
	CALL	SCANB		;Any more parameters?
	JNZ	GETLIST		;If not end-of-line get list
	POP	DI		;Displacement of ENTER
	POP	ES		;Segment
GETROW:
	CALL	OUTDI		;Print address of entry
	CALL	BLANK		;Leave a space
GETBYTE:
	MOV	AL,ES:[DI]		;Get current value
	CALL	HEX		;And display it
	MOV	AL,"."
	CALL	CONOUT		;Prompt for new value
	MOV	CX,2		;Max of 2 digits in new value
	MOV	DX,0		;Intial new value
GETDIG:
	CALL	CONIN		;Get digit from user
	MOV	AH,AL		;Save
	CALL	HEXCHK		;Hex digit?
	XCHG	AH,AL		;Need original for echo
	JC	NOHEX		;If not, try special command
	CALL	CONOUT		;Echo to console
	MOV	DH,DL		;Rotate new value
	MOV	DL,AH		;And include new digit
	LOOP	GETDIG		;At most 2 digits
;We have two digits, so all we will accept now is a command.
WAIT:
	CALL	CONIN		;Get command character
NOHEX:
	CMP	AL,8		;Backspace
	JZ	BS
	CMP	AL,7FH		;RUBOUT
	JZ	BS
	CMP	AL,"-"		;Back up to previous address
	JZ	PREV
	CMP	AL,13		;All done with command?
	JZ	EOL
	CMP	AL," "		;Go to next address
	JZ	NEXT
;If we got here, character was invalid. Sound bell.
	MOV	AL,7
	CALL	CONOUT
	JCXZ	WAIT		;CX=0 means no more digits
	JMP	SHORT GETDIG		;Don't have 2 digits yet
BS:
	CMP	CL,2		;CX=2 means nothing typed yet
	JZ	GETDIG		;Can't back up over nothing
	INC	CL		;Accept one more character
	MOV	DL,DH		;Rotate out last digit
	MOV	DH,CH		;Zero this digit
	CALL	BACKUP		;Physical backspace
	JMP	SHORT GETDIG		;Get more digits

;If new value has been entered, convert it to binary and
;put into memory. Always bump pointer to next location

STORE:
	CMP	CL,2		;CX=2 means nothing typed yet
	JZ	NOSTO		;So no new value to store
;Rotate DH left 4 bits to combine with DL and make a byte value
	PUSH	CX
	MOV	CL,4
	SHL	DH,CL
	POP	CX
	OR	DL,DH		;Hex is now converted to binary
	MOV	ES:[DI],DL		;Store new value
NOSTO:
	INC	DI		;Prepare for next location
	RET
EOL:
	CALL	STORE		;Enter the new value
	JMP	CRLF		;CR/LF and terminate
NEXT:
	CALL	STORE		;Enter new value
	INC	CX		;Leave a space plus two for
	INC	CX		;  each digit not entered
	CALL	TAB
	MOV	AX,DI		;Next memory address
	AND	AL,7		;Check for 8-byte boundary
	JNZ	GETBYTE		;Take 8 per line
NEWROW:
	CALL	CRLF		;Terminate line
	JMP	GETROW		;Print address on new line
PREV:
	CALL	STORE		;Enter the new value
;DI has been bumped to next byte. Drop it 2 to go to previous addr
	DEC	DI
	DEC	DI
	JMP	SHORT NEWROW		;Terminate line after backing up

;Perform register dump if no parameters or set register if a
;register designation is a parameter.

REG:
	CALL	SCANP
	JZ	DISPREG
	MOV	DL,[DI]
	INC	DI
	MOV	DH,[DI]
	CMP	DH,13
	JZ	FLAG
	INC	DI
	CALL	GETEOL
	CMP	DH," "
	JZ	FLAG
	MOV	DI,OFFSET REGTAB
	XCHG	AX,DX
	PUSH	CS
	POP	ES
	MOV	CX,REGTABLEN
	REPNZ	SCASW
	JNZ	BADREG
	OR	CX,CX
	JNZ	NOTPC
	DEC	DI
	DEC	DI
	MOV	AX,CS:[DI-2]
NOTPC:
	CALL	CONOUT
	MOV	AL,AH
	CALL	CONOUT
	CALL	BLANK
	PUSH	DS
	POP	ES
	LEA	BX,[DI+REGDIF-2]
	MOV	DX,[BX]
	CALL	OUT16
	CALL	CRLF
	MOV	AL,":"
	CALL	CONOUT
	CALL	INBUF
	CALL	SCANB
	JZ	RET3
	MOV	CX,4
	CALL	GETHEX1
	CALL	GETEOL
	MOV	[BX],DX
RET3:	RET
BADREG:
	MOV	AX,5200H+"B"	;BR ERROR
	JMP	ERR
DISPREG:
	MOV	SI,OFFSET REGTAB
	MOV	BX,OFFSET AXSAVE
	MOV	CX,8
	CALL	DISPREGLINE
	CALL	CRLF
	MOV	CX,5
	CALL	DISPREGLINE
	CALL	BLANK
	CALL	DISPFLAGS
	JMP	CRLF
FLAG:
	CMP	DL,"F"
	JNZ	BADREG
	CALL	DISPFLAGS
	MOV	AL,"-"
	CALL	CONOUT
	CALL	INBUF
	CALL	SCANB
	XOR	BX,BX
	MOV	DX,[FSAVE]
GETFLG:
	MOV	SI,DI
	LODSW
	CMP	AL,13
	JZ	SAVCHG
	CMP	AH,13
	JZ	FLGERR
	MOV	DI,OFFSET FLAGTAB
	MOV	CX,32
	PUSH	CS
	POP	ES
	REPNE	SCASW
	JNZ	FLGERR
	MOV	CH,CL
	AND	CL,0FH
	MOV	AX,1
	ROL	AX,CL
	TEST	AX,BX
	JNZ	REPFLG
	OR	BX,AX
	OR	DX,AX
	TEST	CH,16
	JNZ	NEXFLG
	XOR	DX,AX
NEXFLG:
	MOV	DI,SI
	PUSH	DS
	POP	ES
	CALL	SCANP
	JMP	SHORT GETFLG
DISPREGLINE:
	LODSW
	CALL	CONOUT
	MOV	AL,AH
	CALL	CONOUT
	MOV	AL,"="
	CALL	CONOUT
	MOV	DX,[BX]
	INC	BX
	INC	BX
	CALL	OUT16
	CALL	BLANK
	CALL	BLANK
	LOOP	DISPREGLINE
	RET
REPFLG:
	MOV	AX,4600H+"D"	;DF ERROR
FERR:
	CALL	SAVCHG
ERR:
	CALL	CONOUT
	MOV	AL,AH
	CALL	CONOUT
	MOV	SI,OFFSET ERRMES
	JMP	PRINT
SAVCHG:
	MOV	[FSAVE],DX
	RET
FLGERR:
	MOV	AX,4600H+"B"	;BF ERROR
	JMP	SHORT FERR
DISPFLAGS:
	MOV	SI,OFFSET FLAGTAB
	MOV	CX,16
	MOV	DX,[FSAVE]
DFLAGS:
	LODSW
	SHL	DX,1
	JC	FLAGSET
	MOV	AX,CS:[SI+30]
FLAGSET:
	OR	AX,AX
	JZ	NEXTFLG
	CALL	CONOUT
	MOV	AL,AH
	CALL	CONOUT
	CALL	BLANK
NEXTFLG:
	LOOP	DFLAGS
	RET

;Trace 1 instruction or the number of instruction specified
;by the parameter using 8086 trace mode. Registers are all
;set according to values in save area

TRACE:
	CALL	SCANP
	CALL	HEXIN
	MOV	DX,1
	JC	STOCNT
	MOV	CX,4
	CALL	GETHEX
STOCNT:
	MOV	[TCOUNT],DX
	CALL	GETEOL
STEP:
	MOV	[BRKCNT],0
	OR	BYTE PTR [FSAVE+1],1
EXIT:
	CLI
	XOR	AX,AX
	MOV	DS,AX			;DS=0: address IVT directly
	MOV	WORD PTR DS:[4],OFFSET REENTER	;INT 1: single-step -> REENTER
	MOV	DS:[6],CS
	MOV	WORD PTR DS:[0CH],OFFSET BREAKFIX	;INT 3: breakpoint -> BREAKFIX
	MOV	DS:[0EH],CS
	MOV	WORD PTR DS:[6CH],OFFSET BREAK	;INT 1Bh: Ctrl-Break -> BREAK
	MOV	DS:[6EH],CS
	PUSH	CS
	POP	DS			;Restore DS=CS
	MOV	SP,OFFSET STACK
	POP	AX
	POP	BX
	POP	CX
	POP	DX
	POP	BP
	POP	BP
	POP	SI
	POP	DI
	POP	ES
	POP	ES
	POP	SS
	MOV	SP,[SPSAVE]
	PUSH	WORD PTR DS:[FSAVE]
	PUSH	WORD PTR DS:[CSSAVE]
	PUSH	WORD PTR DS:[IPSAVE]
	MOV	DS,[DSSAVE]
	IRET
STEP1:	JMP	SHORT STEP

;Re-entry point from breakpoint. Need to decrement instruction
;pointer so it points to location where breakpoint actually
;occured.

BREAKFIX:
	XCHG	SP,BP
	DEC	WORD PTR [BP]
	XCHG	SP,BP

;Re-entry point from trace mode or interrupt during
;execution. All registers are saved so they can be
;displayed or modified.

REENTER:
	MOV	CS:[SPSAVE],SP
	MOV	CS:[SSSAVE],SS
	PUSH	CS
	POP	SS			;SS = monitor's COM segment
	MOV	SP,OFFSET RSTACK
	PUSH	ES
	PUSH	DS
	PUSH	DI
	PUSH	SI
	PUSH	BP
	DEC	SP
	DEC	SP
	PUSH	DX
	PUSH	CX
	PUSH	BX
	PUSH	AX
	PUSH	SS
	POP	DS
	MOV	SP,[SPSAVE]
	MOV	SS,[SSSAVE]
	POP	WORD PTR DS:[IPSAVE]
	POP	WORD PTR DS:[CSSAVE]
	POP	AX
	AND	AH,0FEH
	MOV	[FSAVE],AX
	MOV	[SPSAVE],SP
	PUSH	DS
	POP	ES
	PUSH	DS
	POP	SS
	MOV	SP,OFFSET STACK
	STI
	CLD
	CALL	CRLF
	CALL	DISPREG
	DEC	[TCOUNT]
	JNZ	STEP1
ENDGO:
	MOV	SI,OFFSET BPTAB
	MOV	CX,[BRKCNT]
	JCXZ	COMJMP
CLEARBP:
	MOV	DX,[SI+BPLEN]
	LODSW
	PUSH	AX
	CALL	GETSEG
	MOV	ES,AX
	MOV	DI,DX
	POP	AX
	STOSB
	LOOP	CLEARBP
COMJMP:	JMP	COMMAND

;Input from the specified port and display result

INPUT:
	MOV	CX,4		;Port may have 4 digits
	CALL	GETHEX		;Get port number in DX
	IN	AL,DX		;Variable port input
	CALL	HEX		;And display
	JMP	CRLF

;Output a value to specified port.

OUTPUT:
	MOV	CX,4		;Port may have 4 digits
	CALL	GETHEX		;Get port number
	PUSH	DX		;Save while we get data
	MOV	CX,2		;Byte output only
	CALL	GETHEX		;Get data to output
	XCHG	AX,DX		;Output data in AL
	POP	DX		;Port in DX
	OUT	DX,AL		;Variable port output
	RET

;Jump to program, setting up registers according to the
;save area. Up to 10 breakpoint addresses may be specified.

GO:
	MOV	BX,OFFSET LINEBUF
	XOR	SI,SI
GO1:
	CALL	SCANP
	JZ	EXEC
	MOV	CX,5
	CALL	GETHEX
	MOV	[BX],DX
	MOV	[BX-(BPLEN-1)],AH
	INC	BX
	INC	BX
	INC	SI
	CMP	SI,BPMAX+1
	JNZ	GO1
	MOV	AX,5000H+"B"	;BP ERROR
	JMP	ERR
EXEC:
	MOV	[BRKCNT],SI
	CALL	GETEOL
	MOV	CX,SI
	JCXZ	NOBP
	MOV	SI,OFFSET BPTAB
SETBP:
	MOV	DX,[SI+BPLEN]
	LODSW
	CALL	GETSEG
	MOV	DS,AX
	MOV	DI,DX
	MOV	AL,[DI]
	MOV	BYTE PTR [DI],0CCH
	PUSH	ES
	POP	DS
	MOV	[SI-2],AL
	LOOP	SETBP
NOBP:
	MOV	[TCOUNT],1
	JMP	EXIT

BREAK:
	MOV	AL,'^'
	CALL	CONOUT
	MOV	AL,'C'
	CALL	CONOUT
	CALL	CRLF
	JMP	COMMAND
REGTAB:
	DB	"AXBXCXDXSPBPSIDIDSESSSCSIPPC"
REGDIF		EQU	OFFSET AXSAVE - OFFSET REGTAB

;Flags are ordered to correspond with the bits of the flag
;register, most significant bit first, zero if bit is not
;a flag. First 16 entries are for bit set, second 16 for
;bit reset.

FLAGTAB:
	DW	0
	DW	0
	DW	0
	DW	0
	DB	"OV"
	DB	"DN"
	DB	"EI"
	DW	0
	DB	"NG"
	DB	"ZR"
	DW	0
	DB	"AC"
	DW	0
	DB	"PE"
	DW	0
	DB	"CY"
	DW	0
	DW	0
	DW	0
	DW	0
	DB	"NV"
	DB	"UP"
	DB	"DI"
	DW	0
	DB	"PL"
	DB	"NZ"
	DW	0
	DB	"NA"
	DW	0
	DB	"PO"
	DW	0
	DB	"NC"

HEADER:	DB	13,10,10,"SCP 8086 Monitor 1.9  (? for help)",13,8AH
BYEMES:	DB	13,10,"Returning to DOS...",13,8AH
HELMES:
	DB	13,10,"Commands (addresses and values in hex):",13,10
	DB	"  B                      Reboot (INT 19h)",13,10
	DB	"  D [addr] [Llen|end]    Dump memory (hex+ASCII)",13,10
	DB	"  E addr [bytes]         Enter/edit memory",13,10
	DB	"  F addr Llen|end bytes  Fill memory",13,10
	DB	"  G [addr] [bp..]        Go (run). Up to 10 breakpoints",13,10
	DB	"  I port                 Input byte from port",13,10
	DB	"  M src Llen|end dst     Move (block copy)",13,10
	DB	"  O port byte            Output byte to port",13,10
	DB	"  Q                      Quit to DOS",13,10
	DB	"  R [reg]                Show/set registers or flags (R F)",13,10
	DB	"  S addr Llen|end bytes  Search memory",13,10
	DB	"  T [count]              Trace (single-step)",13,10
	DB	"  ? or help              This help",13,8AH
SYNERR:	DB	'^'
ERRMES:	DB	" Error",13,8AH
BACMES:	DB	8,32,88H

;Help — display command summary

HELP:
	INC	DI		;Step past '?' (matches INC DI in normal dispatch)
	MOV	SI,OFFSET HELMES
	CALL	PRINTMES
	JMP	COMMAND

;Reboot — fire BIOS bootstrap loader (INT 19h)

BOOT:
	INT	19H		;BIOS bootstrap: reboot from first drive
	RET			;Should never return

;Quit — restore IVT vectors and return to DOS

QUIT:
	CLI
	XOR	AX,AX
	MOV	DS,AX			;Address IVT at 0:0
	MOV	AX,[OLDINT1]
	MOV	DS:[4],AX		;Restore INT 1 IP
	MOV	AX,[OLDINT1+2]
	MOV	DS:[6],AX		;Restore INT 1 CS
	MOV	AX,[OLDINT3]
	MOV	DS:[0CH],AX		;Restore INT 3 IP
	MOV	AX,[OLDINT3+2]
	MOV	DS:[0EH],AX		;Restore INT 3 CS
	MOV	AX,[OLDINT1B]
	MOV	DS:[6CH],AX		;Restore INT 1Bh IP
	MOV	AX,[OLDINT1B+2]
	MOV	DS:[6EH],AX		;Restore INT 1Bh CS
	PUSH	CS
	POP	DS			;Restore DS=CS
	STI
	MOV	SI,OFFSET BYEMES
	CALL	PRINTMES
	INT	20H			;Terminate — return to DOS
