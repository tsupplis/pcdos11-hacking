
program     segment
            assume cs:program, ds:program
            org 100h

_start:
            jmp     short display
olddos:
            db "1.x$"
            db "000000"
digitend:   
            db "$"
eol:
            db 0Ah,0Dh,'$'
display:
            mov     ah, 30h
            int     21h
            cmp     al, 1
            jg      newdos
            mov     ah, 9
            mov     dx, offset olddos
            int     21h
            jmp     short exit
newdos:
            push    ax
            xor     ah,ah
            call    convert
            mov     ah, 2
            mov     dl, '.'
            int     21h
            pop     ax
            mov     al, ah
            xor     ah, ah
            call    convert
exit:
            mov     ah, 9
            mov     dx, offset eol
            int     21h
            int     20h
convert:
            mov     bl, 10
            mov     di, offset digitend
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
