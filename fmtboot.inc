; Embedded FORMAT boot sector: 512 bytes.
; Absolute boot references use runtime addresses 0000:7C00..7DFF.
; Include at the desired file placement; do not change the absolute runtime equates.
; Fixed runtime addresses in the sector loaded at 0000:7C00.
; Keep the original layout: these addresses are fixed to the reference image.
b_boot_first_system_chs   equ     7C03h
b_boot_system_sectors     equ     7C05h
b_boot_heads              equ     7D64h
b_boot_sector_size        equ     7D65h
b_boot_failure_text       equ     7D67h
b_boot_bio_name           equ     7D8Bh
b_boot_dos_name           equ     7D97h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Boot-sector entry: short jump over parameter words and reserved header bytes.
; ---------------------------------------------------------------------------

b_start:
                jmp     short b_boot_entry
                nop

; First system CHS: CL=8, CH=0. FORMAT patches this word to 0103h for two sides.
                dw      8h
; Number of system sectors to load (20 decimal).
                dw      14h

; Reserved header bytes.
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h

; ---------------------------------------------------------------------------
; BIOS INT 19h retry path after an unsuccessful system-file name check.
; ---------------------------------------------------------------------------

b_reboot:
                int     19h

; ---------------------------------------------------------------------------
; Set stack 0000:7C00, use 0060h for system loading, and reset floppy drive A.
; ---------------------------------------------------------------------------

b_boot_entry:
                cli
                mov     ax,cs
                mov     ds,ax
                xor     dx,dx
                mov     ss,dx
                mov     sp,7C00h
                sti
                mov     ax,60h
                mov     ds,ax
                mov     es,ax
                xor     dx,dx
                mov     ax,dx
                int     13h
                jc      b_boot_error
                call    b_check_system_names
                jc      b_reboot
                cmp     word ptr cs:[b_boot_first_system_chs],8h
                jz      b_begin_system_reads
                mov     byte ptr cs:[b_boot_heads],2h

b_begin_system_reads:
                mov     bx,0h
                mov     cx,cs:[b_boot_first_system_chs]
                push    cx
                mov     al,9h
                sub     al,cl
                mov     ah,0h
                mov     si,ax

; ---------------------------------------------------------------------------
; Read a chunk with BIOS INT 13h. Update remaining sectors and buffer address.
; ---------------------------------------------------------------------------

b_read_system_chunk:
                push    si
                xor     dx,dx
                xor     ax,ax
                mov     al,ch
                div     byte ptr cs:[b_boot_heads]
                mov     ch,al
                mov     dh,ah
                mov     ax,si
                mov     ah,2h
                int     13h
                jc      b_boot_error
                pop     si
                pop     cx
                sub     cs:[b_boot_system_sectors],si
                jz      b_launch_system
                mov     ax,si
                mul     word ptr cs:[b_boot_sector_size]
                add     bx,ax
                inc     ch
                mov     cl,1h
                push    cx
                mov     si,8h
                cmp     si,cs:[b_boot_system_sectors]
                jl      b_read_next_chunk
                mov     si,cs:[b_boot_system_sectors]

b_read_next_chunk:
                jmp     short b_read_system_chunk

; ---------------------------------------------------------------------------
; Transfer control to the loaded BIOS component at 0060:0000.
; ---------------------------------------------------------------------------

b_launch_system:
                jmp_far 60h, 0h

; ---------------------------------------------------------------------------
; Print the disk boot failure message, then loop indefinitely.
; ---------------------------------------------------------------------------

b_boot_error:
                mov     si,b_boot_failure_text
                call    b_print_boot_string

; ---------------------------------------------------------------------------
; Wait indefinitely after an unrecoverable read/reset failure.
; ---------------------------------------------------------------------------

b_halt_loop:
                jmp     short b_halt_loop

; ---------------------------------------------------------------------------
; CS:SI is a NUL-terminated string; print via BIOS INT 10h teletype output.
; ---------------------------------------------------------------------------

b_print_boot_string:
                xor     bh,bh

b_print_boot_character:
                lodsb_cs
                and     al,7Fh
                jz      b_print_boot_string_ret
                push    si
                mov     ah,0Eh
                mov     bx,7h
                int     10h
                pop     si
                jmp     short b_print_boot_character

b_print_boot_string_ret:
                ret
                jmpn    b_start

; ---------------------------------------------------------------------------
; Read root-directory sector 4; compare its first two entries with system names.
; ---------------------------------------------------------------------------

b_check_system_names:
                mov     bx,0h
                mov     cx,4h
                mov     ax,201h
                int     13h
                push    ds
                jc      b_system_names_missing
                mov     ax,cs
                mov     ds,ax
                mov     di,0h
                mov     cx,0Bh

b_lowercase_root_names:
                or      byte ptr es:[di],20h
                or      byte ptr es:[di+20h],20h
                inc     di
                loop    b_lowercase_root_names
                mov     di,0h
                mov     si,b_boot_bio_name
                mov     cx,0Bh
                cld
                repe    cmpsb
                jnz     b_system_names_missing
                mov     di,20h
                mov     si,b_boot_dos_name
                mov     cx,0Bh
                repe    cmpsb
                jnz     b_system_names_missing
                pop     ds
                ret

b_system_names_missing:
                mov     si,7D1Bh
                call    b_print_boot_string
                mov     ah,0h
                int     16h
                pop     ds
                stc
                ret

; Non-system disk message, terminated by NUL.
                db      0Dh,0Ah
                db      "Non-System disk or disk error"
                db      0Dh,0Ah
                db      "Replace and strike any key when ready"
                db      0Dh,0Ah,0h

; Initial head count (1); boot code sets 2 for the double-sided CHS.
                db      1h

; Bytes per sector.
                dw      200h

; Unrecoverable boot read error message.
                db      0Dh,0Ah
                db      "Disk Boot failure"
                db      0Dh,0Ah,0h

; Vendor marker (not printed).
                db      "Microsoft,Inc "

; First root-directory filename: lowercase 8.3 BIOS component.
IF MSVER
                db      "io      sys"
ELSE
                db      "ibmbio  com"
ENDIF

; Original separator byte; not part of the compared filename.
                db      "0"

; Second root-directory filename: lowercase 8.3 DOS component.
IF MSVER
                db      "msdos   sys"
ELSE
                db      "ibmdos  com"
ENDIF

; Original separator byte.
                db      "0"

; Opaque bytes after the filename table; no boot code references this region.
                db      5h,0C6h,6h
                db      "w/"
                db      0FFh,83h
                db      "~"
                db      0FCh,0h
                db      "u"
                db      0Bh,80h
                db      "~"
                db      0F7h
                db      ";u"
                db      5h,0C6h,6h
                db      "v/"
                db      0FFh,89h,0ECh
                db      "]"
                db      0CAh,4h,0h

; Zero-filled tail, retained byte for byte.
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h

; Existing emulator-compatible signature in the local reference binary.
                dw      0AA55h
