;*-------------------------------------------------------------------------
;  VER.ASM - INT 21h/AH=30h demonstration-version probe
;
;  This utility demonstrates the optional DOSEXT AH=30h dispatcher service.
;  The service returns its major version in AL.  When DOSEXT is absent, the
;  DOS 1.25 BADCALL path returns AL=0 and leaves the other input registers
;  unspecified; report that condition rather than interpreting AH=30h as a
;  version number.
;*-------------------------------------------------------------------------
program     segment
            assume cs:program, ds:program
            org 100h

_start:
            mov     ah, 30h
            int     21h
            or      al, al
            jz      no30
displayversion:
            push    ax
            xor     ah,ah
            call    convert
            mov     ah, 2
            mov     dl, '.'
            int     21h
            pop     ax
            mov     al, ah
            cmp     al, 10
            jge     nz_minor
            push    ax
            mov     ah, 2
            mov     dl, '0'
            int     21h
            pop     ax
nz_minor:
            xor     ah, ah
            call    convert
            jmp     short exit
no30:
            mov     ah, 9
            lea     dx, [noservice]
            int     21h
exit:
            mov     ah, 9
            lea     dx, [eol]
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
noservice:
            db "INT 21h/AH=30h unavailable$"
            db "000000"
digitend:   
            db "$"
eol:
            db 0Ah,0Dh,'$'

program     ends
            end _start
