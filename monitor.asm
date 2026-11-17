        TITLE Boot-only wrapper for the SCP monitor
; Loaded at physical 8000h, executed with CS=DS=ES=SS=0. This gives
; MON.ASM's absolute vector accesses and its own data a common segment.
; B calls handoff directly; Q is omitted from this build.
BOOTMON EQU 1
code    segment
        assume cs:code, ds:code, es:code, ss:code
        org 8000h
entry:  jmp initialize

        include mon.asm

initialize:
        cli
        xor ax,ax
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,7C00h
        cld
        mov si,4
        mov di,offset vectors
        movsw
        movsw
        mov si,0Ch
        movsw
        movsw
        mov si,6Ch
        movsw
        movsw
        sti
        jmp START

handoff:
        cli
        xor ax,ax
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,7C00h
        cld
        mov si,offset vectors
        mov di,4
        movsw
        movsw
        mov di,0Ch
        movsw
        movsw
        mov di,6Ch
        movsw
        movsw
        mov si,9E00h
        mov di,7C00h
        mov cx,256
        rep movsw
        xor dx,dx
        sti
        db 0EAh
        dw 7C00h,0

vectors dw 6 dup (0)
; Fixed 8 KiB allocation; image construction fills the last sector with
; that disk's original DOS boot sector. No hidden/unallocated sectors.
        db (1E00h-($-entry)) dup (0)
        db 512 dup (0)
code    ends
        end
