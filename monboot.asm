        TITLE 320 KiB floppy first stage for MONITOR.BIN
; MONITOR.BIN occupies the last eight clusters, LBA 624..639.
; This loader is intentionally for 40x2x8 media, drive A.
code    segment
        assume cs:code, ds:code
        org 0
entry:  jmp short normalize
        nop
first   dw 624
count   dw 16
normalize:
        db 0EAh
        dw setup,7C0h
setup:
        cli
        xor ax,ax
        mov ss,ax
        mov sp,7C00h
        mov es,ax
        mov ax,cs
        mov ds,ax
        cld
        sti
        xor ax,ax
        xor dx,dx
        int 13h
        jc failed
        mov si,[first]
        mov di,[count]
        mov bx,8000h
next:
        mov bp,3
retry:
        mov ax,si
        xor dx,dx
        mov cx,8
        div cx
        mov cl,dl
        inc cl
        xor dx,dx
        push cx
        mov cx,2
        div cx
        pop cx
        mov ch,al
        mov dh,dl
        xor dl,dl
        mov ax,201h
        int 13h
        jnc advance
        xor ax,ax
        xor dx,dx
        int 13h
        dec bp
        jnz retry
        jmp short failed
advance:
        add bx,512
        inc si
        dec di
        jnz next
        db 0EAh
        dw 8000h,0
failed:
        mov si,offset message
print:
        lodsb
        or al,al
        jz halt
        mov ah,0Eh
        mov bx,7
        int 10h
        jmp short print
halt:   jmp short halt
message db 'Monitor disk read error',0
        db (510-($-entry)) dup (0)
        dw 0AA55h
code    ends
        end entry
