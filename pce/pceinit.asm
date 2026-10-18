;-----------------------------------------------------------------------------
; pce
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; File name:    pceinit.asm
; Created:      2003-04-25 by Hampa Hug <hampa@hampa.ch>
; Copyright:    (C) 2003-2017 Hampa Hug <hampa@hampa.ch>
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; This program is free software. You can redistribute it and / or modify it
; under the terms of the GNU General Public License version 2 as  published
; by the Free Software Foundation.
;
; This program is distributed in the hope  that  it  will  be  useful,  but
; WITHOUT  ANY   WARRANTY,   without   even   the   implied   warranty   of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU  General
; Public License for more details.
;-----------------------------------------------------------------------------


%include "pce.inc"


section .text

	org	0x100

	jmp	start

%define PCE_USE_HOOK_CHECK   1
%define PCE_USE_HOOK         1

%include "pce-lib.inc"

;-----------------------------------------------------------------------------
; void dos_set_time (const void *buf)
;-----------------------------------------------------------------------------
dos_set_time:
	push	bp
	mov	bp, sp
	push	ds

	lds	bx, [bp + 4]

	mov	dx, [bx + 2]		; month / day
	and	dx, 0x7f7f
	add	dx, 0x0101
	mov	cx, [bx]		; year
	mov	ah, 0x2b
	int	0x21			; set date

	mov	cx, [bx + 4]		; hour / minute
	mov	dx, [bx + 6]		; second / centisecond
	mov	ah, 0x2d
	int	0x21			; set time

	pop	ds
	pop	bp
	ret

;-----------------------------------------------------------------------------
start:
	mov	ax, cs
	mov	ds, ax
	cld

	mov	si, 0x0080

	mov	si, buffer

	call	pce_hook_check
	jc	.err_notpce

	mov	ax, PCE_HOOK_GET_TIME_LOCAL
	call	pce_hook
	jc	.err_get

	mov	[si], ax
	mov	[si + 2], bx
	mov	[si + 4], cx
	mov	[si + 6], dx

	push	ds
	push	si
	call	dos_set_time
	add	    sp, 4
	xor	    al, al
.cls:
    mov    ax,0f00h
    int    10h
    push   bx
    mov     ax,0600h
    mov     bh,07h
    mov     cx,0
    mov     dx,184fh
    int     10h
    pop     bx
    mov     dx,0
    mov     ah,02h
    int    10h
	jmp	   .exit

.err_notpce:
	mov	   dx, msg_notpce
	jmp	   .done_err

.err_get:
	mov	   dx, msg_error_get

.done_err:
    mov ah,0x09
    int 0x21
	mov	al, 0x01

.exit:
	mov	ah, 0x4c
	int	0x21
	int	0x20


;-----------------------------------------------------------------------------
section	.data

msg_notpce	db "not running under pce", 0x0d, 0x0a, "$"
msg_error_get	db "reading host time", 0x0d, 0x0a, "$"


;-----------------------------------------------------------------------------
section .bss

buffer		resb	8
