    ORG 100H

program     segment
            assume cs:program, ds:program
            org 100h

_start:
            mov     ax,0f00h
            int     10h
            push    bx
            mov     ax,0600h
            mov     bh,07h
            mov     cx,0
            mov     dx,184fh
            int     10h
            pop     bx
            mov     dx,0
            mov     ah,02h
            int     10h
            int     20h

program     ends
            end _start
