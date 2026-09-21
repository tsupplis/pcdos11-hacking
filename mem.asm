program     segment
            assume cs:program, ds:program
            org 100h

_start:
            clc
            ; Get BIOS Configuration
            int     12h
            jc      short exit
            push    ax
            mov     cl, 6
            mov     bx, cs
            shr     bx, cl
            inc     bx
            sub     ax, bx

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
