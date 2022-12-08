    ORG 100H

program     segment
            assume cs:program, ds:program
            org 100h

_start:
            clc
            ; Get BIOS Configuration
            int     12h
            push    ax
            push    ax
            jc      short exit
            mov     cl, 6
            mov     ax, cs
            shr     ax, cl
            inc     ax
            mov     bx, ax
            pop     ax
            sub     ax, bx

            jmp     short display
digitend:   
            db "K$"
eol:        
            db 0Ah,0Dh,'$'
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

program     ends
            end _start
