;*-------------------------------------------------------------------------
;  FORMAT.ASM - PC DOS 1.10 diskette formatter
;
;  Build: make format.com     Verify: make check-utilities
;  Original: bin/format.com, 3816 bytes; COM load address 0100h.
;  Each emitted line records its COM address and original bytes.
;  File offset = COM address - 0100h. Numeric loc_ / data_ names retain
;  addresses where a fuller semantic name has not yet been established.
;  This is an exact static mapping; runtime behavior has not been tested.
;
;  Layout:
;    0100h-06F4h  code
;    09F2h-0C45h  code
;  All remaining image bytes are initialized data, messages, or tables.
;  Code at 09F2h starts the IBM floppy hardware implementation.
;-------------------------------------------------------------------------

program         segment
                assume  cs:program, ds:program
                org     100h

; Preserve near jumps even when the target is in short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

; Original 8086 group-1 byte operations use opcode 82h in some places.
; MASM emits 80h; rawop records the exact encoding with its mnemonic below.
rawop           macro   b1,b2,b3,b4,b5,b6
                db      b1,b2
                ifnb    <b3>
                db      b3
                endif
                ifnb    <b4>
                db      b4
                endif
                ifnb    <b5>
                db      b5
                endif
                ifnb    <b6>
                db      b6
                endif
                endm

; PSP fields and fixed data addresses (equates do not emit bytes).
; Keep the original layout: these addresses are fixed to the reference image.
data_0002               equ     2h
data_0004               equ     4h
data_005C               equ     5Ch
command_length          equ     80h
command_tail            equ     81h
data_06F5               equ     6F5h
data_0713               equ     713h
data_0718               equ     718h
data_0736               equ     736h
data_074B               equ     74Bh
data_0761               equ     761h
data_0764               equ     764h
data_0780               equ     780h
data_0792               equ     792h
data_07AB               equ     7ABh
data_07B0               equ     7B0h
data_07C3               equ     7C3h
data_07D8               equ     7D8h
data_07FA               equ     7FAh
data_0818               equ     818h
data_0842               equ     842h
data_085C               equ     85Ch
data_0874               equ     874h
data_088C               equ     88Ch
drive_seen              equ     8A9h
fat_initialized         equ     8AAh
target_drive            equ     8ABh
original_drive          equ     8ACh
data_08AD               equ     8ADh
data_08AF               equ     8AFh
data_08B1               equ     8B1h
data_08B3               equ     8B3h
data_08B5               equ     8B5h
data_08B7               equ     8B7h
data_08B9               equ     8B9h
data_08BB               equ     8BBh
data_08BD               equ     8BDh
data_08BF               equ     8BFh
data_08C1               equ     8C1h
data_08C3               equ     8C3h
data_08C5               equ     8C5h
data_08C7               equ     8C7h
data_08CE               equ     8CEh
bio_filename            equ     8CFh
data_08DC               equ     8DCh
data_08E2               equ     8E2h
data_08E4               equ     8E4h
data_08EF               equ     8EFh
data_08F1               equ     8F1h
data_08F3               equ     8F3h
data_08F5               equ     8F5h
data_08FC               equ     8FCh
dos_filename            equ     8FDh
data_090A               equ     90Ah
data_0910               equ     910h
data_0912               equ     912h
data_091D               equ     91Dh
data_091F               equ     91Fh
data_0921               equ     921h
data_0923               equ     923h
data_0931               equ     931h
data_0937               equ     937h
data_0939               equ     939h
data_0944               equ     944h
data_0946               equ     946h
data_0949               equ     949h
data_0950               equ     950h
format_options          equ     976h
saved_options           equ     978h
fat_offset              equ     97Ah
fat_segment             equ     97Ch
sectors_per_cluster     equ     97Eh
bytes_per_sector        equ     980h
system_bytes            equ     982h
total_bytes_low         equ     984h
total_bytes_high        equ     986h
bad_bytes_low           equ     988h
bad_bytes_high          equ     98Ah
system_sector_limit     equ     98Ch
bad_sector_count        equ     98Eh
stack_top               equ     9F0h
option_count            equ     0C46h
option_chars            equ     0C47h
data_0C49               equ     0C49h
data_0C58               equ     0C58h
data_0C6A               equ     0C6Ah
data_0C90               equ     0C90h
data_0CA9               equ     0CA9h
format_id_table         equ     0CBDh
bios_drive              equ     0CDDh
current_cylinder        equ     0CDEh
current_head            equ     0CDFh
format_state            equ     0CE0h
initial_track_bad       equ     0CE1h
retry_count             equ     0CE2h
media_descriptor        equ     0CE3h
reserved_sectors        equ     0CE4h
data_0CE6               equ     0CE6h
boot_image              equ     0CE8h
trailing_bytes          equ     0EE8h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Validate the selected drive and command switches; use the stack ending at 09F0h.
; ---------------------------------------------------------------------------

start:
                mov     sp,stack_top                         ; 0100: BC F0 09
                cmp     al,0FFh                              ; 0103: 3C FF
                jnz     loc_0110                             ; 0105: 75 09
                mov     dx,data_0764                         ; 0107: BA 64 07
                call    print_string                         ; 010A: E8 29 03
                jmpn    terminate                            ; 010D: E9 5F 03

loc_0110:
                mov     ah,19h                               ; 0110: B4 19
                int     21h                                  ; 0112: CD 21
                mov     ds:[original_drive],al               ; 0114: A2 AC 08
                mov     si,5Ch                               ; 0117: BE 5C 00
                lodsb                                        ; 011A: AC
                or      al,al                                ; 011B: 0A C0
                jnz     loc_0124                             ; 011D: 75 05
                mov     al,ds:[original_drive]               ; 011F: A0 AC 08
                inc     al                                   ; 0122: FE C0

loc_0124:
                dec     al                                   ; 0124: FE C8
                mov     ds:[data_005C],al                    ; 0126: A2 5C 00
                mov     ds:[target_drive],al                 ; 0129: A2 AB 08
                xor     bx,bx                                ; 012C: 33 DB
                mov     si,81h                               ; 012E: BE 81 00

loc_0131:
                call    skip_spaces                          ; 0131: E8 45 00
                lodsb                                        ; 0134: AC
                cmp     al,2Fh                               ; 0135: 3C 2F
                jz      loc_014F                             ; 0137: 74 16
                cmp     al,0Dh                               ; 0139: 3C 0D
                jz      options_ready                        ; 013B: 74 47
                lodsb                                        ; 013D: AC
                cmp     al,3Ah                               ; 013E: 3C 3A
                jnz     loc_0170                             ; 0140: 75 2E
                cmp     byte ptr ds:[drive_seen],0h          ; 0142: 80 3E A9 08 00
                jnz     loc_0170                             ; 0147: 75 27
                inc     byte ptr ds:[drive_seen]             ; 0149: FE 06 A9 08
                jmp     short loc_0131                       ; 014D: EB E2

loc_014F:
                lodsb                                        ; 014F: AC
                cmp     al,41h                               ; 0150: 3C 41
                jl      loc_0156                             ; 0152: 7C 02
                and     al,0DFh                              ; 0154: 24 DF

loc_0156:
                mov     cl,ds:[option_count]                 ; 0156: 8A 0E 46 0C
                or      cl,cl                                ; 015A: 0A C9
                jz      loc_0170                             ; 015C: 74 12
                mov     ch,0h                                ; 015E: B5 00
                mov     di,option_chars                      ; 0160: BF 47 0C
                repne   scasb                                ; 0163: F2 AE
                jnz     loc_0170                             ; 0165: 75 09
                mov     ax,1h                                ; 0167: B8 01 00
                shl     ax,cl                                ; 016A: D3 E0
                or      bx,ax                                ; 016C: 0B D8
                jmp     short loc_0131                       ; 016E: EB C1

loc_0170:
                mov     dx,data_0780                         ; 0170: BA 80 07
                call    print_string                         ; 0173: E8 C0 02
                jmpn    terminate                            ; 0176: E9 F6 02

; ---------------------------------------------------------------------------
; Advance DS:SI over spaces and tabs; leave SI on the first other character.
; ---------------------------------------------------------------------------

skip_spaces:
                lodsb                                        ; 0179: AC
                cmp     al,20h                               ; 017A: 3C 20
                jz      skip_spaces                          ; 017C: 74 FB
                cmp     al,9h                                ; 017E: 3C 09
                jz      skip_spaces                          ; 0180: 74 F7
                dec     si                                   ; 0182: 4E
                ret                                          ; 0183: C3

; ---------------------------------------------------------------------------
; Save the parsed /S and /1 flags and prepare optional system-file transfer.
; ---------------------------------------------------------------------------

options_ready:
                mov     ds:[format_options],bx               ; 0184: 89 1E 76 09
                test    word ptr ds:[format_options],1h      ; 0188: F7 06 76 09 01 00
                jz      loc_019F                             ; 018E: 74 0F

loc_0190:
                call    open_system_files                    ; 0190: E8 7C 03
                jnc     loc_019A                             ; 0193: 73 05

loc_0195:
                call    prompt_dos_disk                      ; 0195: E8 D9 02
                jmp     short loc_0190                       ; 0198: EB F6

loc_019A:
                call    read_system_files                    ; 019A: E8 A4 04
                jc      loc_0195                             ; 019D: 72 F6

loc_019F:
                call    hardware_finish                      ; 019F: E8 50 08
                jnc     loc_01AD                             ; 01A2: 73 09
                mov     dx,data_07C3                         ; 01A4: BA C3 07
                call    print_string                         ; 01A7: E8 8C 02
                jmpn    terminate                            ; 01AA: E9 C2 02

loc_01AD:
                mov     dx,ds:[format_options]               ; 01AD: 8B 16 76 09
                mov     ds:[saved_options],dx                ; 01B1: 89 16 78 09

; ---------------------------------------------------------------------------
; Initialize counters, prompt for a diskette, and start the format pass.
; ---------------------------------------------------------------------------

format_another:
                mov     word ptr ds:[bad_bytes_low],0h       ; 01B5: C7 06 88 09 00 00
                mov     word ptr ds:[bad_bytes_high],0h      ; 01BB: C7 06 8A 09 00 00
                mov     word ptr ds:[system_bytes],0h        ; 01C1: C7 06 82 09 00 00
                mov     byte ptr ds:[drive_seen],0h          ; 01C7: C6 06 A9 08 00
                mov     byte ptr ds:[fat_initialized],0h     ; 01CC: C6 06 AA 08 00
                mov     dx,ds:[saved_options]                ; 01D1: 8B 16 78 09
                mov     ds:[format_options],dx               ; 01D5: 89 16 76 09
                mov     al,ds:[target_drive]                 ; 01D9: A0 AB 08
                add     al,41h                               ; 01DC: 04 41
                mov     ds:[data_0713],al                    ; 01DE: A2 13 07
                mov     dx,data_06F5                         ; 01E1: BA F5 06
                call    print_string                         ; 01E4: E8 4F 02
                mov     dx,data_0718                         ; 01E7: BA 18 07
                call    print_string                         ; 01EA: E8 49 02
                call    wait_key                             ; 01ED: E8 5A 02
                call    print_line_end                       ; 01F0: E8 50 02
                call    print_line_end                       ; 01F3: E8 4D 02
                call    hardware_initialize                  ; 01F6: E8 FB 07
                jnc     format_tracks_loop                   ; 01F9: 73 08

loc_01FB:
                mov     dx,data_07B0                         ; 01FB: BA B0 07
                call    print_string                         ; 01FE: E8 35 02
                jmp     short format_another                 ; 0201: EB B2

; ---------------------------------------------------------------------------
; Consume hardware formatter results; mark bad clusters and account for disk space.
; ---------------------------------------------------------------------------

format_tracks_loop:
                call    format_next_tracks                   ; 0203: E8 34 09
                jc      loc_01FB                             ; 0206: 72 F3
                cmp     ax,0h                                ; 0208: 3D 00 00
                jnz     loc_0210                             ; 020B: 75 03
                jmpn    loc_02DC                             ; 020D: E9 CC 00

loc_0210:
                cmp     bx,ds:[reserved_sectors]             ; 0210: 3B 1E E4 0C
                jnl     loc_021E                             ; 0214: 7D 08
                mov     dx,data_07FA                         ; 0216: BA FA 07
                call    print_string                         ; 0219: E8 1A 02
                jmp     short loc_01FB                       ; 021C: EB DD

loc_021E:
                mov     ds:[bad_sector_count],ax             ; 021E: A3 8E 09
                cmp     byte ptr ds:[fat_initialized],0h     ; 0221: 80 3E AA 08 00
                jnz     loc_0231                             ; 0226: 75 09
                inc     byte ptr ds:[fat_initialized]        ; 0228: FE 06 AA 08
                push    bx                                   ; 022C: 53
                call    initialize_fat                       ; 022D: E8 71 02
                pop     bx                                   ; 0230: 5B

loc_0231:
                test    word ptr ds:[format_options],1h      ; 0231: F7 06 76 09 01 00
                jz      loc_026F                             ; 0237: 74 36
                cmp     byte ptr ds:[drive_seen],0h          ; 0239: 80 3E A9 08 00
                jnz     loc_0257                             ; 023E: 75 17
                inc     byte ptr ds:[drive_seen]             ; 0240: FE 06 A9 08
                call    count_system_space                   ; 0244: E8 BF 01
                xor     dx,dx                                ; 0247: 33 D2
                mov     ax,ds:[system_bytes]                 ; 0249: A1 82 09
                div     word ptr ds:[bytes_per_sector]       ; 024C: F7 36 80 09
                add     ax,ds:[reserved_sectors]             ; 0250: 03 06 E4 0C
                mov     ds:[system_sector_limit],ax          ; 0254: A3 8C 09

loc_0257:
                cmp     bx,ds:[system_sector_limit]          ; 0257: 3B 1E 8C 09
                jg      loc_026F                             ; 025B: 7F 12
                mov     dx,data_07D8                         ; 025D: BA D8 07
                call    print_string                         ; 0260: E8 D3 01
                and     word ptr ds:[format_options],0FFFEh  ; 0263: 81 26 76 09 FE FF
                mov     word ptr ds:[system_bytes],0h        ; 0269: C7 06 82 09 00 00

loc_026F:
                mov     ax,ds:[bad_sector_count]             ; 026F: A1 8E 09
                mul     word ptr ds:[bytes_per_sector]       ; 0272: F7 26 80 09
                add     ds:[bad_bytes_low],ax                ; 0276: 01 06 88 09
                jnc     loc_0280                             ; 027A: 73 04
                inc     word ptr ds:[bad_bytes_high]         ; 027C: FF 06 8A 09

loc_0280:
                mov     ax,ds:[bad_sector_count]             ; 0280: A1 8E 09
                div     word ptr ds:[sectors_per_cluster]    ; 0283: F7 36 7E 09
                or      dx,dx                                ; 0287: 0B D2
                jz      loc_028C                             ; 0289: 74 01
                inc     ax                                   ; 028B: 40

loc_028C:
                mov     cx,ax                                ; 028C: 8B C8
                mov     ax,ds:[bad_sector_count]             ; 028E: A1 8E 09
                add     bx,ax                                ; 0291: 03 D8
                sub     bx,ds:[reserved_sectors]             ; 0293: 2B 1E E4 0C
                xchg    ax,bx                                ; 0297: 93
                div     word ptr ds:[sectors_per_cluster]    ; 0298: F7 36 7E 09
                xchg    ax,bx                                ; 029C: 93

loc_029D:
                mov     dx,0FF7h                             ; 029D: BA F7 0F
                call    set_fat12_entry                      ; 02A0: E8 06 00
                dec     bx                                   ; 02A3: 4B
                loop    loc_029D                             ; 02A4: E2 F7
                jmpn    format_tracks_loop                   ; 02A6: E9 5A FF

; ---------------------------------------------------------------------------
; BX=cluster, DX=FAT12 value. Update packed FAT in the saved FAT segment/offset.
; ---------------------------------------------------------------------------

set_fat12_entry:
                push    es                                   ; 02A9: 06
                mov     es,word ptr ds:[fat_segment]         ; 02AA: 8E 06 7C 09
                push    bx                                   ; 02AE: 53
                push    dx                                   ; 02AF: 52
                mov     si,bx                                ; 02B0: 8B F3
                shr     bx,1                                 ; 02B2: D1 EB
                add     bx,ds:[fat_offset]                   ; 02B4: 03 1E 7A 09
                add     bx,si                                ; 02B8: 03 DE
                shr     si,1                                 ; 02BA: D1 EE
                mov     si,es:[bx]                           ; 02BC: 26 8B 37
                jnc     loc_02CF                             ; 02BF: 73 0E
                shl     dx,1                                 ; 02C1: D1 E2
                shl     dx,1                                 ; 02C3: D1 E2
                shl     dx,1                                 ; 02C5: D1 E2
                shl     dx,1                                 ; 02C7: D1 E2
                and     si,0Fh                               ; 02C9: 81 E6 0F 00
                jmp     short loc_02D3                       ; 02CD: EB 04

loc_02CF:
                and     si,0F000h                            ; 02CF: 81 E6 00 F0

loc_02D3:
                or      si,dx                                ; 02D3: 0B F2
                mov     es:[bx],si                           ; 02D5: 26 89 37
                pop     dx                                   ; 02D8: 5A
                pop     bx                                   ; 02D9: 5B
                pop     es                                   ; 02DA: 07
                ret                                          ; 02DB: C3

loc_02DC:
                cmp     byte ptr ds:[fat_initialized],0h     ; 02DC: 80 3E AA 08 00
                jnz     loc_02E9                             ; 02E1: 75 06
                call    initialize_fat                       ; 02E3: E8 BB 01
                call    count_system_space                   ; 02E6: E8 1D 01

loc_02E9:
                push    es                                   ; 02E9: 06
                mov     ax,ds:[fat_segment]                  ; 02EA: A1 7C 09
                mov     es,ax                                ; 02ED: 8E C0
                mov     di,ds:[fat_offset]                   ; 02EF: 8B 3E 7A 09
                mov     byte ptr es:[di-1h],1h               ; 02F3: 26 C6 45 FF 01
                pop     es                                   ; 02F8: 07
                test    word ptr ds:[format_options],1h      ; 02F9: F7 06 76 09 01 00
                jz      loc_030D                             ; 02FF: 74 0C
                call    write_system_files                   ; 0301: E8 CE 02
                call    write_command_file                   ; 0304: E8 98 03
                mov     dx,data_0736                         ; 0307: BA 36 07
                call    print_string                         ; 030A: E8 29 01

loc_030D:
                call    print_line_end                       ; 030D: E8 33 01
                mov     ah,0Dh                               ; 0310: B4 0D
                int     21h                                  ; 0312: CD 21
                call    hardware_finish                      ; 0314: E8 DB 06
                jnc     loc_031C                             ; 0317: 73 03
                jmpn    loc_01FB                             ; 0319: E9 DF FE

loc_031C:
                mov     ax,ds:[total_bytes_low]              ; 031C: A1 84 09
                mul     word ptr ds:[bytes_per_sector]       ; 031F: F7 26 80 09
                mov     cx,ds:[sectors_per_cluster]          ; 0323: 8B 0E 7E 09
                call    scale_cluster_bytes                  ; 0327: E8 D2 00
                mov     ds:[total_bytes_low],ax              ; 032A: A3 84 09
                mov     ds:[total_bytes_high],dx             ; 032D: 89 16 86 09
                mov     si,ax                                ; 0331: 8B F0
                mov     di,dx                                ; 0333: 8B FA
                mov     bx,data_0842                         ; 0335: BB 42 08
                call    print_number                         ; 0338: E8 56 00
                cmp     word ptr ds:[system_bytes],0h        ; 033B: 83 3E 82 09 00
                jz      loc_034E                             ; 0340: 74 0C
                mov     si,ds:[system_bytes]                 ; 0342: 8B 36 82 09
                xor     di,di                                ; 0346: 33 FF
                mov     bx,data_085C                         ; 0348: BB 5C 08
                call    print_number                         ; 034B: E8 43 00

loc_034E:
                cmp     word ptr ds:[bad_bytes_low],0h       ; 034E: 83 3E 88 09 00
                jnz     loc_035C                             ; 0353: 75 07
                cmp     word ptr ds:[bad_bytes_high],0h      ; 0355: 83 3E 8A 09 00
                jz      loc_036A                             ; 035A: 74 0E

loc_035C:
                mov     si,ds:[bad_bytes_low]                ; 035C: 8B 36 88 09
                mov     di,ds:[bad_bytes_high]               ; 0360: 8B 3E 8A 09
                mov     bx,data_0874                         ; 0364: BB 74 08
                call    print_number                         ; 0367: E8 27 00

loc_036A:
                mov     cx,ds:[total_bytes_low]              ; 036A: 8B 0E 84 09
                mov     bx,ds:[total_bytes_high]             ; 036E: 8B 1E 86 09
                sub     cx,ds:[bad_bytes_low]                ; 0372: 2B 0E 88 09
                sbb     bx,ds:[bad_bytes_high]               ; 0376: 1B 1E 8A 09
                sub     cx,ds:[system_bytes]                 ; 037A: 2B 0E 82 09
                sbb     bx,0h                                ; 037E: 83 DB 00
                mov     si,cx                                ; 0381: 8B F1
                mov     di,bx                                ; 0383: 8B FB
                mov     bx,data_088C                         ; 0385: BB 8C 08
                call    print_number                         ; 0388: E8 06 00
                call    ask_another                          ; 038B: E8 AD 00
                jmpn    format_another                       ; 038E: E9 24 FE

; ---------------------------------------------------------------------------
; DI:SI=32-bit number, BX=message. Convert to packed BCD and display decimal bytes.
; ---------------------------------------------------------------------------

print_number:
                push    bx                                   ; 0391: 53
                xor     ax,ax                                ; 0392: 33 C0
                mov     bx,ax                                ; 0394: 8B D8
                mov     bp,ax                                ; 0396: 8B E8
                mov     cx,20h                               ; 0398: B9 20 00

loc_039B:
                shl     si,1                                 ; 039B: D1 E6
                rcl     di,1                                 ; 039D: D1 D7
                xchg    ax,bp                                ; 039F: 95
                call    bcd_double                           ; 03A0: E8 4E 00
                xchg    ax,bp                                ; 03A3: 95
                xchg    ax,bx                                ; 03A4: 93
                call    bcd_double                           ; 03A5: E8 49 00
                xchg    ax,bx                                ; 03A8: 93
                adc     al,0h                                ; 03A9: 14 00
                loop    loc_039B                             ; 03AB: E2 EE
                mov     cx,1810h                             ; 03AD: B9 10 18
                xchg    ax,dx                                ; 03B0: 92
                call    print_digit                          ; 03B1: E8 28 00
                xchg    ax,bx                                ; 03B4: 93
                call    print_bcd_word                       ; 03B5: E8 0E 00
                xchg    ax,bp                                ; 03B8: 95
                call    print_bcd_word                       ; 03B9: E8 0A 00
                pop     dx                                   ; 03BC: 5A
                cmp     dx,0h                                ; 03BD: 83 FA 00
                jz      loc_03C5                             ; 03C0: 74 03
                call    print_string                         ; 03C2: E8 71 00

loc_03C5:
                ret                                          ; 03C5: C3

; ---------------------------------------------------------------------------
; Print packed BCD AX using the common byte and digit routines.
; ---------------------------------------------------------------------------

print_bcd_word:
                push    ax                                   ; 03C6: 50
                mov     dl,ah                                ; 03C7: 8A D4
                call    print_bcd_byte                       ; 03C9: E8 01 00
                pop     dx                                   ; 03CC: 5A

; ---------------------------------------------------------------------------
; Print packed BCD DL as two decimal digits.
; ---------------------------------------------------------------------------

print_bcd_byte:
                mov     dh,dl                                ; 03CD: 8A F2
                shr     dl,1                                 ; 03CF: D0 EA
                shr     dl,1                                 ; 03D1: D0 EA
                shr     dl,1                                 ; 03D3: D0 EA
                shr     dl,1                                 ; 03D5: D0 EA
                call    print_digit                          ; 03D7: E8 02 00
                mov     dl,dh                                ; 03DA: 8A D6

; ---------------------------------------------------------------------------
; Print DL low nibble, tracking leading positions in CH/CL.
; ---------------------------------------------------------------------------

print_digit:
                and     dl,0Fh                               ; 03DC: 80 E2 0F
                jz      loc_03E3                             ; 03DF: 74 02
                mov     cl,0h                                ; 03E1: B1 00

loc_03E3:
                dec     ch                                   ; 03E3: FE CD
                and     cl,ch                                ; 03E5: 22 CD
                or      dl,30h                               ; 03E7: 80 CA 30
                sub     dl,cl                                ; 03EA: 2A D1
                mov     ah,2h                                ; 03EC: B4 02
                int     21h                                  ; 03EE: CD 21
                ret                                          ; 03F0: C3

; ---------------------------------------------------------------------------
; Double packed BCD AX with incoming carry using ADC/DAA.
; ---------------------------------------------------------------------------

bcd_double:
                adc     al,al                                ; 03F1: 12 C0
                daa                                          ; 03F3: 27
                xchg    al,ah                                ; 03F4: 86 C4
                adc     al,al                                ; 03F6: 12 C0
                daa                                          ; 03F8: 27
                xchg    al,ah                                ; 03F9: 86 C4

loc_03FB:
                ret                                          ; 03FB: C3

; ---------------------------------------------------------------------------
; Shift DX:AX left according to the power of two in CX.
; ---------------------------------------------------------------------------

scale_cluster_bytes:
                shr     cx,1                                 ; 03FC: D1 E9
                jc      loc_03FB                             ; 03FE: 72 FB
                shl     ax,1                                 ; 0400: D1 E0
                rcl     dx,1                                 ; 0402: D1 D2
                jmp     short scale_cluster_bytes            ; 0404: EB F6

; ---------------------------------------------------------------------------
; Accumulate rounded allocation sizes for the three system files.
; ---------------------------------------------------------------------------

count_system_space:
                mov     ax,ds:[data_08BF]                    ; 0406: A1 BF 08
                call    round_file_allocation                ; 0409: E8 09 00
                mov     ax,ds:[data_08C1]                    ; 040C: A1 C1 08
                call    round_file_allocation                ; 040F: E8 03 00
                mov     ax,ds:[data_08C3]                    ; 0412: A1 C3 08

; ---------------------------------------------------------------------------
; AX=file bytes. Round to disk allocation units and add to system_bytes.
; ---------------------------------------------------------------------------

round_file_allocation:
                xor     dx,dx                                ; 0415: 33 D2
                div     word ptr ds:[bytes_per_sector]       ; 0417: F7 36 80 09
                or      dx,dx                                ; 041B: 0B D2
                jz      loc_0420                             ; 041D: 74 01
                inc     ax                                   ; 041F: 40

loc_0420:
                push    ax                                   ; 0420: 50
                xor     dx,dx                                ; 0421: 33 D2
                div     word ptr ds:[sectors_per_cluster]    ; 0423: F7 36 7E 09
                pop     ax                                   ; 0427: 58
                or      dx,dx                                ; 0428: 0B D2
                jz      loc_042D                             ; 042A: 74 01
                inc     ax                                   ; 042C: 40

loc_042D:
                mul     word ptr ds:[bytes_per_sector]       ; 042D: F7 26 80 09
                add     ds:[system_bytes],ax                 ; 0431: 01 06 82 09
                ret                                          ; 0435: C3

; ---------------------------------------------------------------------------
; DX points to a dollar-terminated string in DS; print through DOS AH=09h.
; ---------------------------------------------------------------------------

print_string:
                mov     ah,9h                                ; 0436: B4 09
                int     21h                                  ; 0438: CD 21
                ret                                          ; 043A: C3

; ---------------------------------------------------------------------------
; Ask whether to format another diskette; terminate on N.
; ---------------------------------------------------------------------------

ask_another:
                call    ask_yes_no                           ; 043B: E8 12 00
                jc      terminate                            ; 043E: 72 2F
                call    print_line_end                       ; 0440: E8 00 00

; ---------------------------------------------------------------------------
; Print the shared dollar-terminated line ending.
; ---------------------------------------------------------------------------

print_line_end:
                mov     dx,data_0761                         ; 0443: BA 61 07
                call    print_string                         ; 0446: E8 ED FF
                ret                                          ; 0449: C3

; ---------------------------------------------------------------------------
; Flush console input and read a key without echo through DOS AX=0C08h.
; ---------------------------------------------------------------------------

wait_key:
                mov     ax,0C08h                             ; 044A: B8 08 0C
                int     21h                                  ; 044D: CD 21
                ret                                          ; 044F: C3

; ---------------------------------------------------------------------------
; Read Y/N case-insensitively. Return CF=1 for N.
; ---------------------------------------------------------------------------

ask_yes_no:
                mov     dx,data_074B                         ; 0450: BA 4B 07
                call    print_string                         ; 0453: E8 E0 FF
                mov     ax,0C01h                             ; 0456: B8 01 0C
                int     21h                                  ; 0459: CD 21
                and     al,0DFh                              ; 045B: 24 DF
                cmp     al,59h                               ; 045D: 3C 59
                jz      loc_046B                             ; 045F: 74 0A
                cmp     al,4Eh                               ; 0461: 3C 4E
                jz      loc_046A                             ; 0463: 74 05
                call    print_line_end                       ; 0465: E8 DB FF
                jmp     short ask_yes_no                     ; 0468: EB E6

loc_046A:
                stc                                          ; 046A: F9

loc_046B:
                ret                                          ; 046B: C3

loc_046C:
                call    print_string                         ; 046C: E8 C7 FF

terminate:
                int     20h                                  ; 046F: CD 20

; ---------------------------------------------------------------------------
; Request the DOS diskette used to read system files.
; ---------------------------------------------------------------------------

prompt_dos_disk:
                mov     ah,19h                               ; 0471: B4 19
                int     21h                                  ; 0473: CD 21
                add     al,41h                               ; 0475: 04 41
                mov     ds:[data_07AB],al                    ; 0477: A2 AB 07
                mov     dx,data_0792                         ; 047A: BA 92 07
                call    print_string                         ; 047D: E8 B6 FF
                mov     dx,data_0718                         ; 0480: BA 18 07
                call    print_string                         ; 0483: E8 B0 FF
                call    wait_key                             ; 0486: E8 C1 FF
                call    print_line_end                       ; 0489: E8 B7 FF
                ret                                          ; 048C: C3

; ---------------------------------------------------------------------------
; DOS AH=1Ch: retrieve FAT pointer and allocation geometry for target_drive.
; ---------------------------------------------------------------------------

get_disk_allocation:
                mov     dl,ds:[target_drive]                 ; 048D: 8A 16 AB 08
                inc     dl                                   ; 0491: FE C2
                mov     ah,1Ch                               ; 0493: B4 1C
                int     21h                                  ; 0495: CD 21
                or      bx,bx                                ; 0497: 0B DB
                jz      loc_049C                             ; 0499: 74 01
                ret                                          ; 049B: C3

loc_049C:
                mov     dx,data_0764                         ; 049C: BA 64 07
                jmp     short loc_046C                       ; 049F: EB CB

; ---------------------------------------------------------------------------
; Initialize the FAT media bytes and obtain the target allocation geometry.
; ---------------------------------------------------------------------------

initialize_fat:
                call    get_disk_allocation                  ; 04A1: E8 E9 FF
                mov     cs:[fat_offset],bx                   ; 04A4: 2E 89 1E 7A 09
                mov     word ptr cs:[fat_segment],ds         ; 04A9: 2E 8C 1E 7C 09
                mov     al,cs:[media_descriptor]             ; 04AE: 2E A0 E3 0C
                or      al,0F8h                              ; 04B2: 0C F8
                mov     ah,0FFh                              ; 04B4: B4 FF
                mov     di,cs:[fat_offset]                   ; 04B6: 2E 8B 3E 7A 09
                mov     [di],ax                              ; 04BB: 89 05
                mov     [di+2h],ah                           ; 04BD: 88 65 02
                mov     byte ptr [di-1h],1h                  ; 04C0: C6 45 FF 01
                push    es                                   ; 04C4: 06
                pop     ds                                   ; 04C5: 1F
                mov     ah,0Dh                               ; 04C6: B4 0D
                int     21h                                  ; 04C8: CD 21
                call    get_disk_allocation                  ; 04CA: E8 C0 FF
                push    ds                                   ; 04CD: 1E
                push    es                                   ; 04CE: 06
                pop     ds                                   ; 04CF: 1F
                mov     ds:[total_bytes_low],dx              ; 04D0: 89 16 84 09
                mov     ds:[bytes_per_sector],cx             ; 04D4: 89 0E 80 09
                mov     ah,0h                                ; 04D8: B4 00
                mov     ds:[sectors_per_cluster],ax          ; 04DA: A3 7E 09
                shr     dx,1                                 ; 04DD: D1 EA
                jnc     loc_04E2                             ; 04DF: 73 01
                inc     dx                                   ; 04E1: 42

loc_04E2:
                add     dx,ds:[total_bytes_low]              ; 04E2: 03 16 84 09
                xor     ax,ax                                ; 04E6: 33 C0
                pop     es                                   ; 04E8: 07
                mov     cx,dx                                ; 04E9: 8B CA
                mov     di,ds:[fat_offset]                   ; 04EB: 8B 3E 7A 09
                add     di,3h                                ; 04EF: 83 C7 03
                rep     stosb                                ; 04F2: F3 AA
                mov     di,ds:[fat_offset]                   ; 04F4: 8B 3E 7A 09
                mov     byte ptr es:[di-1h],1h               ; 04F8: 26 C6 45 FF 01
                push    ds                                   ; 04FD: 1E
                pop     es                                   ; 04FE: 07
                mov     al,ds:[target_drive]                 ; 04FF: A0 AB 08
                inc     al                                   ; 0502: FE C0
                mov     ds:[data_0950],al                    ; 0504: A2 50 09
                mov     ah,13h                               ; 0507: B4 13
                mov     dx,data_0949                         ; 0509: BA 49 09
                int     21h                                  ; 050C: CD 21
                ret                                          ; 050E: C3

; ---------------------------------------------------------------------------
; Open the BIOS, DOS, and command interpreter files for a /S transfer.
; ---------------------------------------------------------------------------

open_system_files:
                mov     word ptr ds:[data_08C5],0FFFFh       ; 050F: C7 06 C5 08 FF FF
                mov     ax,ds:[data_0002]                    ; 0515: A1 02 00
                mov     cx,cs                                ; 0518: 8C C9
                sub     ax,cx                                ; 051A: 2B C1
                cmp     ax,1000h                             ; 051C: 3D 00 10
                jnl     loc_0528                             ; 051F: 7D 07
                mov     cl,4h                                ; 0521: B1 04
                shl     ax,cl                                ; 0523: D3 E0
                mov     ds:[data_08C5],ax                    ; 0525: A3 C5 08

loc_0528:
                mov     ah,0Fh                               ; 0528: B4 0F
                mov     dx,data_08F5                         ; 052A: BA F5 08
                int     21h                                  ; 052D: CD 21
                or      al,al                                ; 052F: 0A C0
                jz      loc_0535                             ; 0531: 74 02

loc_0533:
                stc                                          ; 0533: F9
                ret                                          ; 0534: C3

loc_0535:
                mov     ax,ds:[data_0910]                    ; 0535: A1 10 09
                mov     ds:[data_08B1],ax                    ; 0538: A3 B1 08
                mov     ax,ds:[data_0912]                    ; 053B: A1 12 09
                mov     ds:[data_08B9],ax                    ; 053E: A3 B9 08
                mov     ah,0Fh                               ; 0541: B4 0F
                mov     dx,data_08C7                         ; 0543: BA C7 08
                int     21h                                  ; 0546: CD 21
                or      al,al                                ; 0548: 0A C0
                jnz     loc_0533                             ; 054A: 75 E7
                mov     ax,ds:[data_08E2]                    ; 054C: A1 E2 08
                mov     ds:[data_08AF],ax                    ; 054F: A3 AF 08
                mov     ax,ds:[data_08E4]                    ; 0552: A1 E4 08
                mov     ds:[data_08B7],ax                    ; 0555: A3 B7 08
                mov     ah,1Ah                               ; 0558: B4 1A
                mov     dx,ds:[data_0CE6]                    ; 055A: 8B 16 E6 0C
                int     21h                                  ; 055E: CD 21
                mov     word ptr ds:[data_091D],0h           ; 0560: C7 06 1D 09 00 00
                mov     word ptr ds:[data_091F],0h           ; 0566: C7 06 1F 09 00 00
                mov     word ptr ds:[data_08EF],0h           ; 056C: C7 06 EF 08 00 00
                mov     word ptr ds:[data_08F1],0h           ; 0572: C7 06 F1 08 00 00
                mov     word ptr ds:[data_090A],1h           ; 0578: C7 06 0A 09 01 00
                mov     word ptr ds:[data_08DC],1h           ; 057E: C7 06 DC 08 01 00
                mov     ah,27h                               ; 0584: B4 27
                mov     dx,data_08F5                         ; 0586: BA F5 08
                mov     cx,ds:[data_08C5]                    ; 0589: 8B 0E C5 08
                sub     cx,ds:[data_0CE6]                    ; 058D: 2B 0E E6 0C
                mov     ds:[data_08C5],cx                    ; 0591: 89 0E C5 08
                int     21h                                  ; 0595: CD 21
                cmp     al,1h                                ; 0597: 3C 01
                jnz     loc_05CF                             ; 0599: 75 34
                mov     ds:[data_0921],cx                    ; 059B: 89 0E 21 09
                mov     ds:[data_08C1],cx                    ; 059F: 89 0E C1 08
                mov     ah,1Ah                               ; 05A3: B4 1A
                mov     dx,ds:[data_0CE6]                    ; 05A5: 8B 16 E6 0C
                add     dx,ds:[data_08C1]                    ; 05A9: 03 16 C1 08
                int     21h                                  ; 05AD: CD 21
                mov     ah,27h                               ; 05AF: B4 27
                mov     dx,data_08C7                         ; 05B1: BA C7 08
                mov     cx,ds:[data_08C5]                    ; 05B4: 8B 0E C5 08
                sub     cx,ds:[data_08C1]                    ; 05B8: 2B 0E C1 08
                mov     ds:[data_08C5],cx                    ; 05BC: 89 0E C5 08
                int     21h                                  ; 05C0: CD 21
                cmp     al,1h                                ; 05C2: 3C 01
                jnz     loc_05CF                             ; 05C4: 75 09
                mov     ds:[data_08F3],cx                    ; 05C6: 89 0E F3 08
                mov     ds:[data_08BF],cx                    ; 05CA: 89 0E BF 08
                ret                                          ; 05CE: C3

loc_05CF:
                jmpn    loc_0696                             ; 05CF: E9 C4 00

; ---------------------------------------------------------------------------
; Write BIOS and DOS system files to the formatted diskette.
; ---------------------------------------------------------------------------

write_system_files:
                mov     al,ds:[target_drive]                 ; 05D2: A0 AB 08
                inc     al                                   ; 05D5: FE C0
                mov     ds:[data_08FC],al                    ; 05D7: A2 FC 08
                mov     ds:[data_08CE],al                    ; 05DA: A2 CE 08
                mov     dx,ds:[data_0CE6]                    ; 05DD: 8B 16 E6 0C
                add     dx,ds:[data_08C1]                    ; 05E1: 03 16 C1 08
                mov     ah,1Ah                               ; 05E5: B4 1A
                int     21h                                  ; 05E7: CD 21
                mov     ax,ds:[data_08AF]                    ; 05E9: A1 AF 08
                mov     ds:[data_08AD],ax                    ; 05EC: A3 AD 08
                mov     ax,ds:[data_08B7]                    ; 05EF: A1 B7 08
                mov     ds:[data_08B5],ax                    ; 05F2: A3 B5 08
                mov     bx,data_08C7                         ; 05F5: BB C7 08
                call    loc_0616                             ; 05F8: E8 1B 00
                mov     ax,ds:[data_08B1]                    ; 05FB: A1 B1 08
                mov     ds:[data_08AD],ax                    ; 05FE: A3 AD 08
                mov     ax,ds:[data_08B9]                    ; 0601: A1 B9 08
                mov     ds:[data_08B5],ax                    ; 0604: A3 B5 08
                mov     dx,ds:[data_0CE6]                    ; 0607: 8B 16 E6 0C
                mov     ah,1Ah                               ; 060B: B4 1A
                int     21h                                  ; 060D: CD 21
                mov     bx,data_08F5                         ; 060F: BB F5 08
                call    loc_0616                             ; 0612: E8 01 00
                ret                                          ; 0615: C3

loc_0616:
                xor     ax,ax                                ; 0616: 33 C0
                mov     [bx+28h],ax                          ; 0618: 89 47 28
                mov     [bx+2Ah],ax                          ; 061B: 89 47 2A
                mov     dx,bx                                ; 061E: 8B D3
                mov     ah,16h                               ; 0620: B4 16
                int     21h                                  ; 0622: CD 21
                mov     word ptr [bx+15h],1h                 ; 0624: C7 47 15 01 00
                mov     ah,28h                               ; 0629: B4 28
                mov     cx,[bx+2Ch]                          ; 062B: 8B 4F 2C
                int     21h                                  ; 062E: CD 21
                mov     ax,ds:[data_08AD]                    ; 0630: A1 AD 08
                mov     [bx+1Bh],ax                          ; 0633: 89 47 1B
                mov     ax,ds:[data_08B5]                    ; 0636: A1 B5 08
                mov     [bx+1Dh],ax                          ; 0639: 89 47 1D
                mov     ah,10h                               ; 063C: B4 10
                int     21h                                  ; 063E: CD 21
                ret                                          ; 0640: C3

; ---------------------------------------------------------------------------
; Read the system files into available memory; CF reports failure.
; ---------------------------------------------------------------------------

read_system_files:
                mov     dx,ds:[data_0CE6]                    ; 0641: 8B 16 E6 0C
                add     dx,ds:[data_08C1]                    ; 0645: 03 16 C1 08
                add     dx,ds:[data_08BF]                    ; 0649: 03 16 BF 08
                mov     ds:[data_08BD],dx                    ; 064D: 89 16 BD 08
                mov     ah,1Ah                               ; 0651: B4 1A
                int     21h                                  ; 0653: CD 21
                mov     dx,data_0923                         ; 0655: BA 23 09
                mov     ah,0Fh                               ; 0658: B4 0F
                int     21h                                  ; 065A: CD 21
                or      al,al                                ; 065C: 0A C0
                jnz     loc_0693                             ; 065E: 75 33
                mov     word ptr ds:[data_0944],0h           ; 0660: C7 06 44 09 00 00
                mov     word ptr ds:[data_0946],0h           ; 0666: C7 06 46 09 00 00
                mov     word ptr ds:[data_0931],1h           ; 066C: C7 06 31 09 01 00
                mov     cx,ds:[data_08C5]                    ; 0672: 8B 0E C5 08
                sub     cx,ds:[data_08BF]                    ; 0676: 2B 0E BF 08
                mov     ax,ds:[data_0937]                    ; 067A: A1 37 09
                mov     ds:[data_08B3],ax                    ; 067D: A3 B3 08
                mov     ax,ds:[data_0939]                    ; 0680: A1 39 09
                mov     ds:[data_08BB],ax                    ; 0683: A3 BB 08
                mov     ah,27h                               ; 0686: B4 27
                int     21h                                  ; 0688: CD 21
                cmp     al,1h                                ; 068A: 3C 01
                jnz     loc_0696                             ; 068C: 75 08
                mov     ds:[data_08C3],cx                    ; 068E: 89 0E C3 08
                ret                                          ; 0692: C3

loc_0693:
                jmp     short loc_06F3                       ; 0693: EB 5E
                nop                                          ; 0695: 90

loc_0696:
                mov     dx,data_0818                         ; 0696: BA 18 08
                call    print_string                         ; 0699: E8 9A FD
                jmpn    terminate                            ; 069C: E9 D0 FD

; ---------------------------------------------------------------------------
; Create and write COMMAND.COM on the target diskette.
; ---------------------------------------------------------------------------

write_command_file:
                mov     al,ds:[target_drive]                 ; 069F: A0 AB 08
                inc     al                                   ; 06A2: FE C0
                mov     ds:[data_0923],al                    ; 06A4: A2 23 09
                mov     dx,data_0923                         ; 06A7: BA 23 09
                mov     ah,16h                               ; 06AA: B4 16
                int     21h                                  ; 06AC: CD 21
                or      al,al                                ; 06AE: 0A C0
                jnz     loc_06F3                             ; 06B0: 75 41
                mov     dx,ds:[data_08BD]                    ; 06B2: 8B 16 BD 08
                mov     ah,1Ah                               ; 06B6: B4 1A
                int     21h                                  ; 06B8: CD 21
                mov     word ptr ds:[data_0944],0h           ; 06BA: C7 06 44 09 00 00
                mov     word ptr ds:[data_0946],0h           ; 06C0: C7 06 46 09 00 00
                mov     word ptr ds:[data_0931],1h           ; 06C6: C7 06 31 09 01 00
                mov     dx,data_0923                         ; 06CC: BA 23 09
                mov     ah,28h                               ; 06CF: B4 28
                mov     cx,ds:[data_08C3]                    ; 06D1: 8B 0E C3 08
                int     21h                                  ; 06D5: CD 21
                or      al,al                                ; 06D7: 0A C0
                jnz     loc_06F3                             ; 06D9: 75 18
                mov     ax,ds:[data_08B3]                    ; 06DB: A1 B3 08
                mov     ds:[data_0937],ax                    ; 06DE: A3 37 09
                mov     ax,ds:[data_08BB]                    ; 06E1: A1 BB 08
                mov     ds:[data_0939],ax                    ; 06E4: A3 39 09
                mov     dx,data_0923                         ; 06E7: BA 23 09
                mov     ah,10h                               ; 06EA: B4 10
                int     21h                                  ; 06EC: CD 21
                or      al,al                                ; 06EE: 0A C0
                jnz     loc_06F3                             ; 06F0: 75 01
                ret                                          ; 06F2: C3

loc_06F3:
                stc                                          ; 06F3: F9
                ret                                          ; 06F4: C3

; data_06F5 (06F5h)
                db      "Insert new diskette for drive "      ; 06F5: 30 data bytes

; data_0713 (0713h)
                db      "x:"                                  ; 0713: 78 3A
                db      0Dh,0Ah                               ; 0715: 0D 0A
                db      "$"                                   ; 0717: 24

; data_0718 (0718h)
                db      "and strike any key when ready$"      ; 0718: 30 data bytes

; data_0736 (0736h)
                db      "System transferred"                  ; 0736: 18 data bytes
                db      0Dh,0Ah                               ; 0748: 0D 0A
                db      "$"                                   ; 074A: 24

; data_074B (074Bh)
                db      "Format another (Y/N)?$"              ; 074B: 22 data bytes

; data_0761 (0761h)
                db      0Dh,0Ah                               ; 0761: 0D 0A
                db      "$"                                   ; 0763: 24

; data_0764 (0764h)
                db      "Invalid drive specification$"        ; 0764: 28 data bytes

; data_0780 (0780h)
                db      "Invalid parameter$"                  ; 0780: 18 data bytes

; data_0792 (0792h)
                db      "Insert DOS disk in drive "           ; 0792: 25 data bytes

; data_07AB (07ABh)
                db      "x:"                                  ; 07AB: 78 3A
                db      0Dh,0Ah                               ; 07AD: 0D 0A
                db      "$"                                   ; 07AF: 24

; data_07B0 (07B0h)
                db      "Format failure"                      ; 07B0: 14 data bytes
                db      0Dh,0Ah,0Dh,0Ah                       ; 07BE: 0D 0A 0D 0A
                db      "$"                                   ; 07C2: 24

; data_07C3 (07C3h)
                db      "Fatal format error"                  ; 07C3: 18 data bytes
                db      0Dh,0Ah                               ; 07D5: 0D 0A
                db      "$"                                   ; 07D7: 24

; data_07D8 (07D8h)
                db      "Disk unsuitable for system disk"     ; 07D8: 31 data bytes
                db      0Dh,0Ah                               ; 07F7: 0D 0A
                db      "$"                                   ; 07F9: 24

; data_07FA (07FAh)
                db      "Track 0 bad - disk unusable"         ; 07FA: 27 data bytes
                db      0Dh,0Ah                               ; 0815: 0D 0A
                db      "$"                                   ; 0817: 24

; data_0818 (0818h)
                db      "Insufficient memory for system transfer"; 0818: 39 data bytes
                db      0Dh,0Ah                               ; 083F: 0D 0A
                db      "$"                                   ; 0841: 24

; data_0842 (0842h)
                db      " bytes total disk space"             ; 0842: 23 data bytes
                db      0Dh,0Ah                               ; 0859: 0D 0A
                db      "$"                                   ; 085B: 24

; data_085C (085Ch)
                db      " bytes used by system"               ; 085C: 21 data bytes
                db      0Dh,0Ah                               ; 0871: 0D 0A
                db      "$"                                   ; 0873: 24

; data_0874 (0874h)
                db      " bytes in bad sectors"               ; 0874: 21 data bytes
                db      0Dh,0Ah                               ; 0889: 0D 0A
                db      "$"                                   ; 088B: 24

; data_088C (088Ch)
                db      " bytes available on disk"            ; 088C: 24 data bytes
                db      0Dh,0Ah,0Dh,0Ah                       ; 08A4: 0D 0A 0D 0A
                db      "$"                                   ; 08A8: 24

; drive_seen (08A9h)
                db      0h                                    ; 08A9: 00

; fat_initialized (08AAh)
                db      0h                                    ; 08AA: 00

; target_drive (08ABh)
                db      0h                                    ; 08AB: 00

; original_drive (08ACh)
                db      0h                                    ; 08AC: 00

; data_08AD (08ADh)
                db      0h,0h                                 ; 08AD: 00 00

; data_08AF (08AFh)
                db      0h,0h                                 ; 08AF: 00 00

; data_08B1 (08B1h)
                db      0h,0h                                 ; 08B1: 00 00

; data_08B3 (08B3h)
                db      0h,0h                                 ; 08B3: 00 00

; data_08B5 (08B5h)
                db      0h,0h                                 ; 08B5: 00 00

; data_08B7 (08B7h)
                db      0h,0h                                 ; 08B7: 00 00

; data_08B9 (08B9h)
                db      0h,0h                                 ; 08B9: 00 00

; data_08BB (08BBh)
                db      0h,0h                                 ; 08BB: 00 00

; data_08BD (08BDh)
                db      0h,0h                                 ; 08BD: 00 00

; data_08BF (08BFh)
                db      0h,0h                                 ; 08BF: 00 00

; data_08C1 (08C1h)
                db      0h,0h                                 ; 08C1: 00 00

; data_08C3 (08C3h)
                db      0h,0h                                 ; 08C3: 00 00

; data_08C5 (08C5h)
                db      0h,0h                                 ; 08C5: 00 00

; data_08C7 (08C7h)
                db      0FFh,0h,0h,0h,0h,0h,6h                ; 08C7: FF 00 00 00 00 00 06

; data_08CE (08CEh)
                db      0h                                    ; 08CE: 00

; bio_filename (08CFh)
                db      "IBMBIO  COM"                         ; 08CF: 49 42 4D 42 49 4F 20 20 43 4F 4D
                db      4h,0h                                 ; 08DA: 04 00

; data_08DC (08DCh)
                db      0h,0h,0h,0h,0h,0h                     ; 08DC: 00 00 00 00 00 00

; data_08E2 (08E2h)
                db      0h,0h                                 ; 08E2: 00 00

; data_08E4 (08E4h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h      ; 08E4: 00 00 00 00 00 00 00 00 00 00 00

; data_08EF (08EFh)
                db      0h,0h                                 ; 08EF: 00 00

; data_08F1 (08F1h)
                db      0h,0h                                 ; 08F1: 00 00

; data_08F3 (08F3h)
                db      0h,0h                                 ; 08F3: 00 00

; data_08F5 (08F5h)
                db      0FFh,0h,0h,0h,0h,0h,6h                ; 08F5: FF 00 00 00 00 00 06

; data_08FC (08FCh)
                db      0h                                    ; 08FC: 00

; dos_filename (08FDh)
                db      "IBMDOS  COM"                         ; 08FD: 49 42 4D 44 4F 53 20 20 43 4F 4D
                db      4h,0h                                 ; 0908: 04 00

; data_090A (090Ah)
                db      0h,0h,0h,0h,0h,0h                     ; 090A: 00 00 00 00 00 00

; data_0910 (0910h)
                db      0h,0h                                 ; 0910: 00 00

; data_0912 (0912h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h      ; 0912: 00 00 00 00 00 00 00 00 00 00 00

; data_091D (091Dh)
                db      0h,0h                                 ; 091D: 00 00

; data_091F (091Fh)
                db      0h,0h                                 ; 091F: 00 00

; data_0921 (0921h)
                db      0h,0h                                 ; 0921: 00 00

; data_0923 (0923h)
                db      0h                                    ; 0923: 00
                db      "COMMAND COM"                         ; 0924: 43 4F 4D 4D 41 4E 44 20 43 4F 4D
                db      0h,0h                                 ; 092F: 00 00

; data_0931 (0931h)
                db      0h,0h,0h,0h,0h,0h                     ; 0931: 00 00 00 00 00 00

; data_0937 (0937h)
                db      0h,0h                                 ; 0937: 00 00

; data_0939 (0939h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h      ; 0939: 00 00 00 00 00 00 00 00 00 00 00

; data_0944 (0944h)
                db      0h,0h                                 ; 0944: 00 00

; data_0946 (0946h)
                db      0h,0h,0h                              ; 0946: 00 00 00

; data_0949 (0949h)
                db      0FFh,0h,0h,0h,0h,0h,6h                ; 0949: FF 00 00 00 00 00 06

; data_0950 (0950h)
                db      0h                                    ; 0950: 00
                db      "???????????"                         ; 0951: 3F 3F 3F 3F 3F 3F 3F 3F 3F 3F 3F
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 095C: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0968: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h                                 ; 0974: 00 00

; format_options (0976h)
                db      0h,0h                                 ; 0976: 00 00

; saved_options (0978h)
                db      0h,0h                                 ; 0978: 00 00

; fat_offset (097Ah)
                db      0h,0h                                 ; 097A: 00 00

; fat_segment (097Ch)
                db      0h,0h                                 ; 097C: 00 00

; sectors_per_cluster (097Eh)
                db      0h,0h                                 ; 097E: 00 00

; bytes_per_sector (0980h)
                db      0h,0h                                 ; 0980: 00 00

; system_bytes (0982h)
                db      0h,0h                                 ; 0982: 00 00

; total_bytes_low (0984h)
                db      0h,0h                                 ; 0984: 00 00

; total_bytes_high (0986h)
                db      0h,0h                                 ; 0986: 00 00

; bad_bytes_low (0988h)
                db      0h,0h                                 ; 0988: 00 00

; bad_bytes_high (098Ah)
                db      0h,0h                                 ; 098A: 00 00

; system_sector_limit (098Ch)
                db      0h,0h                                 ; 098C: 00 00

; bad_sector_count (098Eh)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 098E: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 099A: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 09A6: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 09B2: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 09BE: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 09CA: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 09D6: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 09E2: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h                                 ; 09EE: 00 00

; stack_top (09F0h)
                db      0E8h,0Ch                              ; 09F0: E8 0C

; ---------------------------------------------------------------------------
; Hardware completion hook: this implementation simply returns with CF clear.
; ---------------------------------------------------------------------------

hardware_finish:
                clc                                          ; 09F2: F8
                ret                                          ; 09F3: C3

; ---------------------------------------------------------------------------
; Initialize BIOS drive state, probe heads, and choose single/double-sided geometry.
; ---------------------------------------------------------------------------

hardware_initialize:
                mov     al,ds:[target_drive]                 ; 09F4: A0 AB 08
                mov     ds:[bios_drive],al                   ; 09F7: A2 DD 0C
                push    ds                                   ; 09FA: 1E
                mov     bx,50h                               ; 09FB: BB 50 00
                mov     ds,bx                                ; 09FE: 8E DB
                mov     ds:[data_0004],al                    ; 0A00: A2 04 00
                pop     ds                                   ; 0A03: 1F
                int     11h                                  ; 0A04: CD 11
                and     ax,0C0h                              ; 0A06: 25 C0 00
                jnz     loc_0A10                             ; 0A09: 75 05
                mov     byte ptr ds:[bios_drive],0h          ; 0A0B: C6 06 DD 0C 00

loc_0A10:
                mov     byte ptr ds:[current_head],1h        ; 0A10: C6 06 DF 0C 01
                mov     byte ptr ds:[current_cylinder],0h    ; 0A15: C6 06 DE 0C 00
                mov     byte ptr ds:[initial_track_bad],0h   ; 0A1A: C6 06 E1 0C 00
                mov     byte ptr ds:[media_descriptor],0FFh  ; 0A1F: C6 06 E3 0C FF
                mov     word ptr ds:[reserved_sectors],9h    ; 0A24: C7 06 E4 0C 09 00
                test    word ptr ds:[format_options],2h      ; 0A2A: F7 06 76 09 02 00
                jz      loc_0A3D                             ; 0A30: 74 0B
                mov     byte ptr ds:[media_descriptor],0FEh  ; 0A32: C6 06 E3 0C FE
                mov     word ptr ds:[reserved_sectors],6h    ; 0A37: C7 06 E4 0C 06 00

loc_0A3D:
                mov     dx,data_0C49                         ; 0A3D: BA 49 0C
                call    hardware_print                       ; 0A40: E8 FE 01
                mov     byte ptr ds:[retry_count],3h         ; 0A43: C6 06 E2 0C 03

loc_0A48:
                call    reset_disk                           ; 0A48: E8 91 00
                jnc     loc_0A57                             ; 0A4B: 73 0A
                call    handle_disk_error                    ; 0A4D: E8 C2 00
                cmp     byte ptr ds:[retry_count],0h         ; 0A50: 80 3E E2 0C 00
                jnz     loc_0A48                             ; 0A55: 75 F1

loc_0A57:
                mov     byte ptr ds:[retry_count],3h         ; 0A57: C6 06 E2 0C 03

loc_0A5C:
                mov     dh,ds:[current_head]                 ; 0A5C: 8A 36 DF 0C
                mov     ch,0h                                ; 0A60: B5 00
                call    format_track                         ; 0A62: E8 87 00
                jnc     loc_0A78                             ; 0A65: 73 11
                call    handle_disk_error                    ; 0A67: E8 A8 00
                cmp     byte ptr ds:[retry_count],0h         ; 0A6A: 80 3E E2 0C 00
                jnz     loc_0A5C                             ; 0A6F: 75 EB
                mov     byte ptr ds:[initial_track_bad],1h   ; 0A71: C6 06 E1 0C 01
                clc                                          ; 0A76: F8
                ret                                          ; 0A77: C3

loc_0A78:
                mov     byte ptr ds:[retry_count],3h         ; 0A78: C6 06 E2 0C 03
                dec     byte ptr ds:[current_head]           ; 0A7D: FE 0E DF 0C
                jz      loc_0A5C                             ; 0A81: 74 D9
                inc     byte ptr ds:[current_head]           ; 0A83: FE 06 DF 0C
                mov     byte ptr ds:[format_state],0h        ; 0A87: C6 06 E0 0C 00

loc_0A8C:
                mov     dh,ds:[current_head]                 ; 0A8C: 8A 36 DF 0C
                mov     ch,0h                                ; 0A90: B5 00
                call    verify_track                         ; 0A92: E8 74 00
                jnc     loc_0ABA                             ; 0A95: 73 23
                call    handle_disk_error                    ; 0A97: E8 78 00
                cmp     byte ptr ds:[retry_count],0h         ; 0A9A: 80 3E E2 0C 00
                jnz     loc_0A8C                             ; 0A9F: 75 EB
                cmp     byte ptr ds:[current_head],0h        ; 0AA1: 80 3E DF 0C 00
                jnz     loc_0AAF                             ; 0AA6: 75 07
                mov     byte ptr ds:[initial_track_bad],1h   ; 0AA8: C6 06 E1 0C 01
                clc                                          ; 0AAD: F8
                ret                                          ; 0AAE: C3

loc_0AAF:
                mov     byte ptr ds:[media_descriptor],0FEh  ; 0AAF: C6 06 E3 0C FE
                mov     word ptr ds:[reserved_sectors],6h    ; 0AB4: C7 06 E4 0C 06 00

loc_0ABA:
                cmp     byte ptr ds:[media_descriptor],0FEh  ; 0ABA: 80 3E E3 0C FE
                jz      loc_0AD1                             ; 0ABF: 74 10
                mov     byte ptr ds:[retry_count],3h         ; 0AC1: C6 06 E2 0C 03
                inc     byte ptr ds:[current_head]           ; 0AC6: FE 06 DF 0C
                cmp     byte ptr ds:[current_head],1h        ; 0ACA: 80 3E DF 0C 01
                jz      loc_0A8C                             ; 0ACF: 74 BB

loc_0AD1:
                inc     byte ptr ds:[current_cylinder]       ; 0AD1: FE 06 DE 0C
                mov     byte ptr ds:[current_head],0h        ; 0AD5: C6 06 DF 0C 00
                clc                                          ; 0ADA: F8
                ret                                          ; 0ADB: C3

; ---------------------------------------------------------------------------
; Reset the floppy controller through BIOS INT 13h AH=00h.
; ---------------------------------------------------------------------------

reset_disk:
                mov     al,8h                                ; 0ADC: B0 08
                mov     cx,1h                                ; 0ADE: B9 01 00
                mov     dl,ds:[bios_drive]                   ; 0AE1: 8A 16 DD 0C
                xor     dh,dh                                ; 0AE5: 32 F6
                mov     ah,0h                                ; 0AE7: B4 00
                int     13h                                  ; 0AE9: CD 13
                ret                                          ; 0AEB: C3

; ---------------------------------------------------------------------------
; Populate track/head bytes in eight sector IDs and call BIOS format AH=05h.
; ---------------------------------------------------------------------------

format_track:
                mov     di,1h                                ; 0AEC: BF 01 00
                mov     bx,bios_drive                        ; 0AEF: BB DD 0C
                mov     al,8h                                ; 0AF2: B0 08

loc_0AF4:
                sub     bx,4h                                ; 0AF4: 83 EB 04
                mov     [bx],ch                              ; 0AF7: 88 2F
                mov     [bx+di],dh                           ; 0AF9: 88 31
                dec     al                                   ; 0AFB: FE C8
                jnz     loc_0AF4                             ; 0AFD: 75 F5
                mov     dl,ds:[bios_drive]                   ; 0AFF: 8A 16 DD 0C
                mov     ax,508h                              ; 0B03: B8 08 05
                int     13h                                  ; 0B06: CD 13
                ret                                          ; 0B08: C3

; ---------------------------------------------------------------------------
; Verify eight sectors through BIOS INT 13h AH=04h.
; ---------------------------------------------------------------------------

verify_track:
                mov     al,8h                                ; 0B09: B0 08
                mov     cl,1h                                ; 0B0B: B1 01
                mov     ah,4h                                ; 0B0D: B4 04
                int     13h                                  ; 0B0F: CD 13
                ret                                          ; 0B11: C3

; ---------------------------------------------------------------------------
; Handle write protection and not-ready errors; reset and decrement retry count.
; ---------------------------------------------------------------------------

handle_disk_error:
                cmp     ah,3h                                ; 0B12: 80 FC 03
                jnz     loc_0B27                             ; 0B15: 75 10
                mov     dx,data_0C6A                         ; 0B17: BA 6A 0C

loc_0B1A:
                call    hardware_print                       ; 0B1A: E8 24 01
                mov     ah,0h                                ; 0B1D: B4 00
                int     13h                                  ; 0B1F: CD 13
                add     sp,2h                                ; 0B21: 83 C4 02
                jmpn    loc_0C04                             ; 0B24: E9 DD 00

loc_0B27:
                cmp     ah,80h                               ; 0B27: 80 FC 80
                jnz     loc_0B31                             ; 0B2A: 75 05
                mov     dx,data_0CA9                         ; 0B2C: BA A9 0C
                jmp     short loc_0B1A                       ; 0B2F: EB E9

loc_0B31:
                mov     ah,0h                                ; 0B31: B4 00
                int     13h                                  ; 0B33: CD 13
                dec     byte ptr ds:[retry_count]            ; 0B35: FE 0E E2 0C
                ret                                          ; 0B39: C3

; ---------------------------------------------------------------------------
; Format and verify tracks, returning bad sector ranges or zero on completion.
; ---------------------------------------------------------------------------

format_next_tracks:
                mov     byte ptr ds:[retry_count],3h         ; 0B3A: C6 06 E2 0C 03
                cmp     byte ptr ds:[initial_track_bad],0h   ; 0B3F: 80 3E E1 0C 00
                jz      loc_0B53                             ; 0B44: 74 0D
                mov     byte ptr ds:[initial_track_bad],0h   ; 0B46: C6 06 E1 0C 00
                mov     bx,0h                                ; 0B4B: BB 00 00
                mov     ax,8h                                ; 0B4E: B8 08 00
                clc                                          ; 0B51: F8
                ret                                          ; 0B52: C3

loc_0B53:
                call    reset_disk                           ; 0B53: E8 86 FF
                jnc     loc_0B62                             ; 0B56: 73 0A
                call    handle_disk_error                    ; 0B58: E8 B7 FF
                cmp     byte ptr ds:[retry_count],0h         ; 0B5B: 80 3E E2 0C 00
                jnz     loc_0B53                             ; 0B60: 75 F1

loc_0B62:
                mov     byte ptr ds:[retry_count],3h         ; 0B62: C6 06 E2 0C 03
                mov     byte ptr ds:[format_state],1h        ; 0B67: C6 06 E0 0C 01

loc_0B6C:
                mov     dh,ds:[current_head]                 ; 0B6C: 8A 36 DF 0C
                mov     ch,ds:[current_cylinder]             ; 0B70: 8A 2E DE 0C
                call    format_track                         ; 0B74: E8 75 FF
                jnc     loc_0B86                             ; 0B77: 73 0D
                call    handle_disk_error                    ; 0B79: E8 96 FF
                cmp     byte ptr ds:[retry_count],0h         ; 0B7C: 80 3E E2 0C 00
                jnz     loc_0B6C                             ; 0B81: 75 E9
                jmpn    report_bad_track                     ; 0B83: E9 80 00

loc_0B86:
                mov     byte ptr ds:[retry_count],3h         ; 0B86: C6 06 E2 0C 03
                mov     byte ptr ds:[format_state],0h        ; 0B8B: C6 06 E0 0C 00

loc_0B90:
                mov     dh,ds:[current_head]                 ; 0B90: 8A 36 DF 0C
                mov     ch,ds:[current_cylinder]             ; 0B94: 8A 2E DE 0C
                call    verify_track                         ; 0B98: E8 6E FF
                jnc     loc_0BAA                             ; 0B9B: 73 0D
                call    handle_disk_error                    ; 0B9D: E8 72 FF
                cmp     byte ptr ds:[retry_count],0h         ; 0BA0: 80 3E E2 0C 00
                jnz     loc_0B90                             ; 0BA5: 75 E9
                jmp     short report_bad_track               ; 0BA7: EB 5D
                nop                                          ; 0BA9: 90

loc_0BAA:
                cmp     byte ptr ds:[media_descriptor],0FEh  ; 0BAA: 80 3E E3 0C FE
                jz      loc_0BC3                             ; 0BAF: 74 12
                inc     byte ptr ds:[current_head]           ; 0BB1: FE 06 DF 0C
                cmp     byte ptr ds:[current_head],1h        ; 0BB5: 80 3E DF 0C 01
                jnz     loc_0BBE                             ; 0BBA: 75 02
                jmp     short loc_0B62                       ; 0BBC: EB A4

loc_0BBE:
                mov     byte ptr ds:[current_head],0h        ; 0BBE: C6 06 DF 0C 00

loc_0BC3:
                mov     ch,ds:[current_cylinder]             ; 0BC3: 8A 2E DE 0C
                inc     ch                                   ; 0BC7: FE C5
                mov     ds:[current_cylinder],ch             ; 0BC9: 88 2E DE 0C
                cmp     ch,28h                               ; 0BCD: 80 FD 28
                jz      write_boot_sector                    ; 0BD0: 74 02
                jmp     short loc_0B62                       ; 0BD2: EB 8E

; ---------------------------------------------------------------------------
; Write the embedded 512-byte boot image through DOS INT 26h; pop its saved flags.
; ---------------------------------------------------------------------------

write_boot_sector:
                mov     bx,boot_image                        ; 0BD4: BB E8 0C
                cmp     byte ptr ds:[media_descriptor],0FEh  ; 0BD7: 80 3E E3 0C FE
                jz      loc_0BE3                             ; 0BDC: 74 05
                mov     word ptr [bx+3h],103h                ; 0BDE: C7 47 03 03 01

loc_0BE3:
                mov     dx,0h                                ; 0BE3: BA 00 00
                mov     cx,1h                                ; 0BE6: B9 01 00
                mov     ah,0h                                ; 0BE9: B4 00
                mov     al,ds:[target_drive]                 ; 0BEB: A0 AB 08
                int     26h                                  ; 0BEE: CD 26
                jc      loc_0BFD                             ; 0BF0: 72 0B
                mov     dx,data_0C58                         ; 0BF2: BA 58 0C
                call    hardware_print                       ; 0BF5: E8 49 00
                popf                                         ; 0BF8: 9D
                xor     ax,ax                                ; 0BF9: 33 C0
                clc                                          ; 0BFB: F8
                ret                                          ; 0BFC: C3

loc_0BFD:
                popf                                         ; 0BFD: 9D
                mov     dx,data_0C90                         ; 0BFE: BA 90 0C
                call    hardware_print                       ; 0C01: E8 3D 00

loc_0C04:
                stc                                          ; 0C04: F9
                ret                                          ; 0C05: C3

; ---------------------------------------------------------------------------
; Compute the failed track sector range and advance the hardware formatting cursor.
; ---------------------------------------------------------------------------

report_bad_track:
                mov     bh,0h                                ; 0C06: B7 00
                mov     bl,ds:[current_cylinder]             ; 0C08: 8A 1E DE 0C
                cmp     byte ptr ds:[media_descriptor],0FEh  ; 0C0C: 80 3E E3 0C FE
                jz      loc_0C19                             ; 0C11: 74 06
                shl     bl,1                                 ; 0C13: D0 E3
                add     bl,ds:[current_head]                 ; 0C15: 02 1E DF 0C

loc_0C19:
                shl     bx,1                                 ; 0C19: D1 E3
                shl     bx,1                                 ; 0C1B: D1 E3
                shl     bx,1                                 ; 0C1D: D1 E3
                mov     ax,8h                                ; 0C1F: B8 08 00
                cmp     byte ptr ds:[media_descriptor],0FEh  ; 0C22: 80 3E E3 0C FE
                jz      loc_0C36                             ; 0C27: 74 0D
                cmp     byte ptr ds:[current_head],1h        ; 0C29: 80 3E DF 0C 01
                jz      loc_0C36                             ; 0C2E: 74 06
                inc     byte ptr ds:[current_head]           ; 0C30: FE 06 DF 0C
                jmp     short loc_0C3F                       ; 0C34: EB 09

loc_0C36:
                inc     byte ptr ds:[current_cylinder]       ; 0C36: FE 06 DE 0C
                mov     byte ptr ds:[current_head],0h        ; 0C3A: C6 06 DF 0C 00

loc_0C3F:
                clc                                          ; 0C3F: F8
                ret                                          ; 0C40: C3

; ---------------------------------------------------------------------------
; Display a dollar-terminated hardware status string at DS:DX.
; ---------------------------------------------------------------------------

hardware_print:
                mov     ah,9h                                ; 0C41: B4 09
                int     21h                                  ; 0C43: CD 21
                ret                                          ; 0C45: C3

; option_count (0C46h)
                db      2h                                    ; 0C46: 02

; option_chars (0C47h)
                db      "1S"                                  ; 0C47: 31 53

; data_0C49 (0C49h)
                db      "Formatting...$0"                     ; 0C49: 15 data bytes

; data_0C58 (0C58h)
                db      "Format complete"                     ; 0C58: 15 data bytes
                db      0Dh,0Ah                               ; 0C67: 0D 0A
                db      "$"                                   ; 0C69: 24

; data_0C6A (0C6Ah)
                db      0Dh,0Ah                               ; 0C6A: 0D 0A
                db      "Attempted write-protect violation"   ; 0C6C: 33 data bytes
                db      0Dh,0Ah                               ; 0C8D: 0D 0A
                db      "$"                                   ; 0C8F: 24

; data_0C90 (0C90h)
                db      0Dh,0Ah                               ; 0C90: 0D 0A
                db      "Unable to write BOOT"                ; 0C92: 20 data bytes
                db      0Dh,0Ah                               ; 0CA6: 0D 0A
                db      "$"                                   ; 0CA8: 24

; data_0CA9 (0CA9h)
                db      0Dh,0Ah                               ; 0CA9: 0D 0A
                db      "Drive not ready"                     ; 0CAB: 15 data bytes
                db      0Dh,0Ah                               ; 0CBA: 0D 0A
                db      "$"                                   ; 0CBC: 24

; format_id_table (0CBDh)
                db      0h,0h,1h,2h,0h,0h,2h,2h,0h,0h,3h,2h   ; 0CBD: 00 00 01 02 00 00 02 02 00 00 03 02
                db      0h,0h,4h,2h,0h,0h,5h,2h,0h,0h,6h,2h   ; 0CC9: 00 00 04 02 00 00 05 02 00 00 06 02
                db      0h,0h,7h,2h,0h,0h,8h,2h               ; 0CD5: 00 00 07 02 00 00 08 02

; bios_drive (0CDDh)
                db      0h                                    ; 0CDD: 00

; current_cylinder (0CDEh)
                db      0h                                    ; 0CDE: 00

; current_head (0CDFh)
                db      0h                                    ; 0CDF: 00

; format_state (0CE0h)
                db      0h                                    ; 0CE0: 00

; initial_track_bad (0CE1h)
                db      0h                                    ; 0CE1: 00

; retry_count (0CE2h)
                db      0h                                    ; 0CE2: 00

; media_descriptor (0CE3h)
                db      0h                                    ; 0CE3: 00

; reserved_sectors (0CE4h)
                db      0h,0h                                 ; 0CE4: 00 00

; data_0CE6 (0CE6h)
                db      0E8h,0Eh                              ; 0CE6: E8 0E

; boot_image (0CE8h): runtime 0000:7C00, file offset 0BE8h.
                include fmtboot.inc

; trailing_bytes (0EE8h)
                db      88h,0h,0EBh                           ; 0EE8: 88 00 EB
                db      "C"                                   ; 0EEB: 43
                db      8Ah                                   ; 0EEC: 8A
                db      "^"                                   ; 0EED: 5E
                db      0Ah,0B7h,0h,0D1h,0E3h,8Bh,87h,92h     ; 0EEE: 0A B7 00 D1 E3 8B 87 92
                db      ";"                                   ; 0EF6: 3B
                db      89h                                   ; 0EF7: 89
                db      "F"                                   ; 0EF8: 46
                db      0FCh,8Bh                              ; 0EF9: FC 8B
                db      "F"                                   ; 0EFB: 46
                db      8h,89h                                ; 0EFC: 08 89
                db      "F"                                   ; 0EFE: 46
                db      0FAh,8Ah                              ; 0EFF: FA 8A
                db      "^"                                   ; 0F01: 5E
                db      0Ah,0B7h,0h,8Ah,87h,95h               ; 0F02: 0A B7 00 8A 87 95
                db      "8"                                   ; 0F08: 38
                db      88h                                   ; 0F09: 88
                db      "F"                                   ; 0F0A: 46
                db      0F9h,0B4h,0h,0D1h,0E0h,89h,0C3h,0FFh,87h,98h; 0F0B: F9 B4 00 D1 E0 89 C3 FF 87 98
                db      "4"                                   ; 0F15: 34
                db      0B8h,5h,0h                            ; 0F16: B8 05 00
                db      "P"                                   ; 0F19: 50
                db      8Dh                                   ; 0F1A: 8D
                db      "F"                                   ; 0F1B: 46
                db      0F9h                                  ; 0F1C: F9
                db      "P"                                   ; 0F1D: 50
                db      0B0h,2h                               ; 0F1E: B0 02
                db      "P"                                   ; 0F20: 50
                db      0FFh                                  ; 0F21: FF
                db      "64"                                  ; 0F22: 36 34
                db      1Ch,9Ah,14h,0Ah                       ; 0F24: 1C 9A 14 0A
                db      "r"                                   ; 0F28: 72
                db      4h,83h,6h                             ; 0F29: 04 83 06
                db      "4"                                   ; 0F2C: 34
                db      1Ch,5h,89h,0ECh                       ; 0F2D: 1C 05 89 EC
                db      "]"                                   ; 0F31: 5D
                db      0CAh,6h,0h                            ; 0F32: CA 06 00
                db      "U"                                   ; 0F35: 55
                db      8Bh,0ECh                              ; 0F36: 8B EC
                db      "Q"                                   ; 0F38: 51
                db      0B8h,1Eh,3h                           ; 0F39: B8 1E 03
                db      "P"                                   ; 0F3C: 50
                db      9Ah                                   ; 0F3D: 9A
                db      "<"                                   ; 0F3E: 3C
                db      0h                                    ; 0F3F: 00
                db      "O"                                   ; 0F40: 4F
                db      4h,9Ah                                ; 0F41: 04 9A
                db      "2"                                   ; 0F43: 32
                db      1h,0E8h,5h,0B8h                       ; 0F44: 01 E8 05 B8
                db      "#"                                   ; 0F48: 23
                db      3h                                    ; 0F49: 03
                db      "P"                                   ; 0F4A: 50
                db      9Ah                                   ; 0F4B: 9A
                db      "<"                                   ; 0F4C: 3C
                db      0h                                    ; 0F4D: 00
                db      "O"                                   ; 0F4E: 4F
                db      4h,8Ah,1Eh                            ; 0F4F: 04 8A 1E
                db      "T"                                   ; 0F52: 54
                db      1Eh,0B7h,0h,0D1h,0E3h,8Bh             ; 0F53: 1E B7 00 D1 E3 8B
                db      "F"                                   ; 0F59: 46
                db      6h                                    ; 0F5A: 06
                db      "+"                                   ; 0F5B: 2B
                db      87h,9Dh                               ; 0F5C: 87 9D
                db      "/P"                                  ; 0F5E: 2F 50
                db      0B0h,4h                               ; 0F60: B0 04
                db      "P"                                   ; 0F62: 50
                db      9Ah,15h,1h                            ; 0F63: 9A 15 01
                db      "O"                                   ; 0F66: 4F
                db      4h,9Ah                                ; 0F67: 04 9A
                db      "="                                   ; 0F69: 3D
                db      1h                                    ; 0F6A: 01
                db      "O"                                   ; 0F6B: 4F
                db      4h,89h,0ECh                           ; 0F6C: 04 89 EC
                db      "]"                                   ; 0F6F: 5D
                db      0CAh,2h,0h                            ; 0F70: CA 02 00
                db      "U"                                   ; 0F73: 55
                db      8Bh,0ECh                              ; 0F74: 8B EC
                db      "Q"                                   ; 0F76: 51
                db      0A1h,0Ch,1Ch,89h                      ; 0F77: A1 0C 1C 89
                db      "F"                                   ; 0F7B: 46
                db      0FEh,0C7h,6h,0Ch,1Ch,0h,0h,0B8h       ; 0F7C: FE C7 06 0C 1C 00 00 B8
                db      "*"                                   ; 0F84: 2A
                db      3h                                    ; 0F85: 03
                db      "P"                                   ; 0F86: 50
                db      9Ah,83h,0h,0E8h,5h,0FFh               ; 0F87: 9A 83 00 E8 05 FF
                db      "v"                                   ; 0F8D: 76
                db      4h,9Ah,85h,3h,80h,5h,83h              ; 0F8E: 04 9A 85 03 80 05 83
                db      "~"                                   ; 0F95: 7E
                db      0FEh,0h                               ; 0F96: FE 00
                db      "t"                                   ; 0F98: 74
                db      0Dh,8Bh                               ; 0F99: 0D 8B
                db      "F"                                   ; 0F9B: 46
                db      0FEh,0A3h,0Ch,1Ch,0C7h                ; 0F9C: FE A3 0C 1C C7
                db      "F"                                   ; 0FA1: 46
                db      0FEh,0h,0h,0EBh,0DCh,89h,0ECh         ; 0FA2: FE 00 00 EB DC 89 EC
                db      "]"                                   ; 0FA9: 5D
                db      0C2h,2h,0h                            ; 0FAA: C2 02 00
                db      "U"                                   ; 0FAD: 55
                db      8Bh,0ECh,83h,0ECh,16h,9Ah             ; 0FAE: 8B EC 83 EC 16 9A
                db      "K"                                   ; 0FB4: 4B
                db      1h                                    ; 0FB5: 01
                db      "O"                                   ; 0FB6: 4F
                db      4h,0B4h,0h,89h                        ; 0FB7: 04 B4 00 89
                db      "F"                                   ; 0FBB: 46
                db      0FEh,8Bh                              ; 0FBC: FE 8B
                db      "F"                                   ; 0FBE: 46
                db      6h,0B1h,8h,0D3h,0E0h,3h               ; 0FBF: 06 B1 08 D3 E0 03
                db      "F"                                   ; 0FC5: 46
                db      0FEh,89h                              ; 0FC6: FE 89
                db      "F"                                   ; 0FC8: 46
                db      0F4h,8Bh,0Eh,1Ch,1Ch,3h,0C8h,89h      ; 0FC9: F4 8B 0E 1C 1C 03 C8 89
                db      "N"                                   ; 0FD1: 4E
                db      0F8h,5h,8Dh                           ; 0FD2: F8 05 8D
                db      "@"                                   ; 0FD5: 40
                db      89h                                   ; 0FD6: 89
                db      "F"                                   ; 0FD7: 46
                db      0F6h,8Dh                              ; 0FD8: F6 8D
                db      "F"                                   ; 0FDA: 46
                db      0EAh                                  ; 0FDB: EA
                db      "P"                                   ; 0FDC: 50
                db      8Dh                                   ; 0FDD: 8D
                db      "F"                                   ; 0FDE: 46
                db      0EBh                                  ; 0FDF: EB
                db      "P"                                   ; 0FE0: 50
                db      8Dh                                   ; 0FE1: 8D
                db      "F"                                   ; 0FE2: 46
                db      0FCh                                  ; 0FE3: FC
                db      "P"                                   ; 0FE4: 50
                db      8Dh                                   ; 0FE5: 8D
                db      "F"                                   ; 0FE6: 46
                db      0F0h                                  ; 0FE7: F0

program         ends
                end     start
