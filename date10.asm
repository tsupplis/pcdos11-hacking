;*-------------------------------------------------------------------------
;  DATE10.ASM - IBM Personal Computer DOS date command, Version 1.00
;
;  Build:   make date10.com
;           (msmasm dosdate10 -> link date10 -> exe2bin date10.exe date10.com)
;
;  Purpose:
;     Displays the current DOS date and optionally changes it through
;     INT 21h Functions 2Ah (Get Date) and 2Bh (Set Date).  This is the
;     compact PC-DOS 1.0 external DATE command, not the later COMMAND.COM
;     built-in implementation.
;
;  Interaction:
;     The display is MM-DD-YY.  The input accepts one or two decimal digits
;     for month and day, and either a two- or four-digit year.  A two-digit
;     year is interpreted as 2000-2099; a four-digit year is literal.  DOS
;     validates the result.  Empty input exits; an invalid result re-prompts.
;
;  Memory (COM image, org 100h):
;     0100h-01C5h   code; 01C6h-01F8h messages; 01F9h-01FBh input header.
;     The DOS input characters and stack share the remaining COM segment;
;     the original sets SP to 0288h.
;
;  Reconstruction:
;     Recreated from date10.dis and date10.xxd, disassemblies of DATE10.COM
;     from PC-DOS 1.0.  The 82h CMP macro and raw MOV SP encoding retain
;     encodings MASM 1.10 would otherwise change.  The original's two-digit
;     1900-based year is deliberately extended to a 2000-based year, changing
;     only the immediate operand in the supplied 252-byte COM.
;-------------------------------------------------------------------------
program segment
        assume cs:program, ds:program
        org 100h

cr equ 0Dh
dos_print equ 9
dos_input equ 0Ah
dos_getdate equ 2Ah
dos_setdate equ 2Bh
two_digit_year_base equ 2000

cmp82_si macro imm
        db 82h,3Ch,imm
        endm
jmpn macro target
        db 0E9h
        dw target - $ - 2
        endm
; MASM 1.10 inserts NOP after MOV SP,imm; original does not.
movsp macro value
        db 0BCh
        dw value
        endm

start:
        movsp stack_top
        mov dx,offset current_date
        mov ah,dos_print
        int 21h
        mov ah,dos_getdate
        int 21h                 ; CX=year, DH=month, DL=day
        mov al,dh
        call print_two
        mov al,'-'
        call print_char
        mov al,dl
        call print_two
        mov al,'-'
        call print_char
        sub cx,1900
        cmp cx,100
        jb short year_ready
        sub cx,100
year_ready:
        mov al,cl
        call print_two

prompt:
        mov dx,offset enter_date
        mov ah,dos_print
        int 21h
        mov ah,dos_input
        mov dx,offset input_buffer
        int 21h
        mov si,offset input_text
        cmp82_si cr
        jz short exit
        call read_number
        mov dh,ah
        call skip_separator
        call read_number
        mov dl,ah
        call skip_separator
        call read_number
        mov cx,two_digit_year_base
        cmp82_si cr
        jz short year_complete
        mov al,100
        mul ah
        mov cx,ax
        call read_number
year_complete:
        mov al,ah
        mov ah,0
        add cx,ax
        mov ah,dos_setdate
        int 21h
        or al,al
        jnz short invalid_input
exit:
        int 20h

; Original accepts '/' or '-' and falls through to invalid_input otherwise.
skip_separator:
        lodsb
        cmp al,'/'
        jz short read_number_done
        cmp al,'-'
        jz short read_number_done

invalid_input:
        mov dx,offset invalid_date
        mov ah,dos_print
        int 21h
        movsp stack_top
        jmpn prompt

read_number:
        call read_digit
        jc short invalid_input
        mov ah,al
        call read_digit
        jc short read_number_done
        aad
        mov ah,al
read_number_done:
        ret

read_digit:
        mov al,[si]
        sub al,'0'
        jb short read_number_done
        cmp al,10
        cmc
        jb short read_number_done
        inc si
        ret

print_two:
        aam
        xchg al,ah
        or ax,3030h
        call print_char
        mov al,ah
print_char:
        xchg ax,dx
        push ax
        mov ah,2
        int 21h
        pop ax
        xchg ax,dx
        ret

invalid_date db cr,10,'Invalid date$'
current_date db 'Current date is $'
enter_date db cr,10,'Enter new date: $'
input_buffer db 12,0
input_text db 0
stack_top equ 288h
program ends
        end start
