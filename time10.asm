;*-------------------------------------------------------------------------
;  TIME10.ASM - IBM Personal Computer DOS time command, Version 1.00
;
;  Build:   make time10.com
;           (msmasm dostime10 -> link time10 -> exe2bin time10.exe time10.com)
;
;  Purpose:
;     Displays the current DOS time and, on request, changes it through
;     INT 21h Functions 2Ch (Get Time) and 2Dh (Set Time).  This is the
;     compact PC-DOS 1.0 external TIME command, not the later COMMAND.COM
;     built-in implementation.
;
;  Interaction:
;     The display is HH:MM:SS.HH (hundredths).  Input is parsed as hours and
;     minutes separated by ':', optionally followed by seconds and hundredths
;     separated by '.'.  DOS performs range validation; an unsuccessful Set
;     Time call prints "Invalid time" and re-prompts.
;
;  Memory (COM image, org 100h):
;     0100h-01C3h   code
;     01C4h-01F6h   messages
;     01F7h-01F9h   DOS buffered-input header and first character slot
;     01FAh-0285h   input characters and stack area, supplied by the COM
;                   segment; SP is set to 0286h, exactly as in the binary.
;
;  Reconstruction:
;     Recreated from time10.dis and time10.xxd, disassemblies of TIME10.COM
;     from PC-DOS 1.0.  The macro below retains the original 82h encoding of
;     CMP r/m8,imm8.  This source is intended to reassemble byte-for-byte to
;     the supplied 250-byte COM.
;-------------------------------------------------------------------------

program	segment
	assume	cs:program, ds:program
	org	100h

cr		equ	0Dh
dos_print	equ	9
dos_input	equ	0Ah
dos_gettime	equ	2Ch
dos_settime	equ	2Dh

; The original uses opcode 82h rather than MASM's normal 80h encoding.
cmp82_si	macro	imm
	db	82h, 3Ch, imm
	endm

; The original deliberately uses a near JMP for this backward branch.
jmpn	macro	target
	db	0E9h
	dw	target - $ - 2
	endm

; MASM 1.10 inserts a NOP after MOV SP,imm; the original does not.
movsp	macro	value
	db	0BCh
	dw	value
	endm

start:
	movsp	stack_top
	mov	dx, offset current_time
	mov	ah, dos_print
	int	21h

	mov	ah, dos_gettime
	int	21h			; CH=hour, CL=minute, DH=second, DL=hundredths
	mov	al, ch
	call	print_two
	mov	al, ':'
	call	print_char
	mov	al, cl
	call	print_two
	mov	al, ':'
	call	print_char
	mov	al, dh
	call	print_two
	mov	al, '.'
	call	print_char
	mov	al, dl
	call	print_two

prompt:
	mov	dx, offset enter_time
	mov	ah, dos_print
	int	21h
	mov	ah, dos_input
	mov	dx, offset input_buffer
	int	21h

	mov	si, offset input_text
	xor	cx, cx
	xor	dx, dx
	mov	bl, ':'
	call	read_field
	jz	short exit
	mov	ch, ah
	call	read_field
	jz	short set_time
	mov	cl, ah
	mov	bl, '.'
	call	read_field
	jz	short set_time
	mov	dh, ah
	mov	bl, cr
	call	read_field
	jz	short set_time
	mov	dl, ah
set_time:
	mov	ah, dos_settime
	int	21h
	or	al, al
	jnz	short invalid_input
exit:
	int	20h

invalid_input:
	mov	dx, offset invalid_time
	mov	ah, dos_print
	int	21h
	movsp	stack_top
	jmpn	prompt

; Read one or two decimal digits into AH, then require the delimiter in BL
; (or a CR).  The condition flags are preserved exactly as in the binary for
; the callers above, including its compact empty/optional-field handling.
read_field:
	call	read_digit
	jc	short invalid_input
	jz	short field_return
	mov	ah, al
	call	read_digit
	jbe	short field_single
	aad
	mov	ah, al
field_single:
	cmp82_si cr
	jz	short field_cr
	lodsb
	cmp	al, bl
	jnz	short invalid_input
field_cr:
	or	al, 0FFh
field_return:
	ret

; Read a digit from DS:SI.  A CR and invalid characters take field_return;
; valid digits advance SI and retain the flags produced by the original code.
read_digit:
	mov	al, [si]
	cmp	al, cr
	jz	short field_return
	sub	al, '0'
	jb	short field_return
	cmp	al, 10
	cmc
	jb	short field_return
	inc	si
	ret

; Print AL as exactly two decimal digits.
print_two:
	aam
	xchg	al, ah
	or	ax, 3030h
	call	print_char
	mov	al, ah

; Print AL while preserving both AX and DX.
print_char:
	xchg	ax, dx
	push	ax
	mov	ah, 2
	int	21h
	pop	ax
	xchg	ax, dx
	ret

invalid_time	db	cr, 10, 'Invalid time$'
current_time	db	'Current time is $'
enter_time	db	cr, 10, 'Enter new time: $'
input_buffer	db	12, 0
input_text	db	0

stack_top	equ	286h

program	ends
	end	start
