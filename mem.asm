;*-------------------------------------------------------------------------
;  MEM.ASM - Simple demonstration tool: current DOS allocation limit
;
;  Reports the size of the current program's PSP memory block in KiB, followed
;  by the BIOS conventional-memory total.  PSP:0002h is DOS's first unavailable
;  segment, so this remains meaningful when DOS and COMMAND are relocated high.
;*-------------------------------------------------------------------------
program     segment
            assume cs:program, ds:program
            org 100h

_start:
            clc
            ; BIOS conventional-memory total, in KiB.
            int     12h
            jc      short exit
            push    ax

            ; The COM program's CS is its PSP segment.  PSP:0002h is the
            ; first segment outside the block DOS assigned to this program.
            mov     ax, cs:[2]
            mov     bx, cs
            sub     ax, bx
            mov     cl, 6
            shr     ax, cl           ; paragraphs to KiB

display:
            call    convert
            mov     ah, 2
            mov     dl, '/'
            int     21h
            pop     ax
            call    convert
exit:
            mov     ah, 9
            lea     dx, [eol]
            int     21h
            int     20h
convert:
            mov     bl, 10
            lea     di, [digitend]
cvtloop:
            dec     di
            div     bl
            add     ah, '0'
            mov     [di], ah
            xor     ah, ah
            test    al, al
            jnz     short cvtloop
            mov     ah, 9
            mov     dx, di
            int     21h
            ret

            db "000000"
digitend:   
            db "K$"
eol:        
            db 0Ah,0Dh,'$'

program     ends
            end _start
