;*-------------------------------------------------------------------------
;  DISKCOPY.ASM - PC DOS 1.10 Diskette Copier
;
;  Build: make diskcopy.com     Verify: make check-utilities
;  Original: bin/diskcopy.com, 2008 bytes; COM load address 0100h.
;  Each emitted line records its COM address and original bytes.
;  File offset = COM address - 0100h. Numeric loc_ / data_ names retain
;  addresses where a fuller semantic name has not yet been established.
;  This is an exact static mapping; runtime behavior has not been tested.
;
;  Layout:
;    0100h-0102h  code
;    019Dh-0534h  code
;    07ACh-0886h  code
;  All remaining image bytes are initialized data, messages, or tables.
;  The disk utilities reuse their initialization area as transfer storage.
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
                db      b1,b2,b3
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
psp_end_segment         equ     2h
fcb1_drive              equ     5Ch
fcb1_name               equ     5Dh
fcb2_drive              equ     6Ch
fcb2_name               equ     6Dh
command_length          equ     80h
command_tail            equ     81h
current_track           equ     535h
tracks_per_buffer       equ     536h
end_track               equ     537h
copy_flags              equ     538h
read_retries            equ     539h
write_retries           equ     53Ah
verify_retries          equ     53Bh
format_retries          equ     53Ch
other_side              equ     53Dh
buffer_segment          equ     53Eh
format_id_table         equ     542h
data_057F               equ     57Fh
data_05A1               equ     5A1h
data_05A6               equ     5A6h
data_05C8               equ     5C8h
data_05CD               equ     5CDh
data_05EB               equ     5EBh
data_066F               equ     66Fh
data_0677               equ     677h
data_0678               equ     678h
data_0680               equ     680h
data_0685               equ     685h
data_06AA               equ     6AAh
data_06D2               equ     6D2h
data_0711               equ     711h
data_0733               equ     733h
data_0749               equ     749h
data_0753               equ     753h
data_075F               equ     75Fh
data_077D               equ     77Dh
data_0790               equ     790h
data_0798               equ     798h
data_07A0               equ     7A0h
data_07A7               equ     7A7h
data_0887               equ     887h
data_08A0               equ     8A0h
data_08B7               equ     8B7h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; COM entry point. DOS supplies the PSP and parsed default FCBs.
; ---------------------------------------------------------------------------

start:
                jmpn    init                                 ; 0100: E9 A9 06
                db      "The IBM Personal Computer Diskette Copie"; 0103: 40 data bytes
                db      "r Version 1.10 (C)Copyright IBM Corp 198"; 012B: 40 data bytes
                db      "1, 1982 Licensed Material - Program Prop"; 0153: 40 data bytes
                db      "erty of IBM Author - David Litton "  ; 017B: 34 data bytes

; ---------------------------------------------------------------------------
; Prompt, read source tracks, write/verify target tracks, then offer another copy.
; ---------------------------------------------------------------------------

copy_again:
                mov     dx,data_057F                         ; 019D: BA 7F 05
                mov     ah,9h                                ; 01A0: B4 09
                int     21h                                  ; 01A2: CD 21
                test    byte ptr ds:[copy_flags],1h          ; 01A4: F6 06 38 05 01
                jz      loc_01B5                             ; 01A9: 74 0A
                mov     dx,data_05CD                         ; 01AB: BA CD 05
                int     21h                                  ; 01AE: CD 21
                call    wait_key                             ; 01B0: E8 8D 00
                jmp     short loc_01B8                       ; 01B3: EB 03

loc_01B5:
                call    prompt_target                        ; 01B5: E8 7C 00

loc_01B8:
                call    read_source_tracks                   ; 01B8: E8 8C 00
                test    byte ptr ds:[copy_flags],1h          ; 01BB: F6 06 38 05 01
                jz      loc_01C5                             ; 01C0: 74 03
                call    prompt_target                        ; 01C2: E8 6F 00

loc_01C5:
                call    write_target_tracks                  ; 01C5: E8 6F 01
                rawop   82h,3Eh,35h,5h,28h                   ; 01C8: 82 3E 35 05 28 ; cmp byte ptr ds:[current_track],28h
                jnz     prompt_source_if_needed              ; 01CD: 75 54
                mov     dx,data_0685                         ; 01CF: BA 85 06
                test    byte ptr ds:[copy_flags],20h         ; 01D2: F6 06 38 05 20
                jnz     loc_01DC                             ; 01D7: 75 03
                mov     dx,data_05EB                         ; 01D9: BA EB 05

loc_01DC:
                mov     ah,9h                                ; 01DC: B4 09
                int     21h                                  ; 01DE: CD 21

loc_01E0:
                mov     dx,data_0733                         ; 01E0: BA 33 07
                mov     ah,9h                                ; 01E3: B4 09
                int     21h                                  ; 01E5: CD 21
                mov     ax,0C01h                             ; 01E7: B8 01 0C
                int     21h                                  ; 01EA: CD 21
                or      al,20h                               ; 01EC: 0C 20
                cmp     al,6Eh                               ; 01EE: 3C 6E
                jnz     loc_01F4                             ; 01F0: 75 02
                int     20h                                  ; 01F2: CD 20

loc_01F4:
                cmp     al,79h                               ; 01F4: 3C 79
                jnz     loc_01E0                             ; 01F6: 75 E8
                mov     sp,100h                              ; 01F8: BC 00 01
                mov     byte ptr ds:[current_track],0h       ; 01FB: C6 06 35 05 00
                test    byte ptr ds:[copy_flags],2h          ; 0200: F6 06 38 05 02
                jnz     loc_021B                             ; 0205: 75 14
                mov     byte ptr ds:[other_side],1h          ; 0207: C6 06 3D 05 01
                test    byte ptr ds:[copy_flags],40h         ; 020C: F6 06 38 05 40
                jz      loc_021B                             ; 0211: 74 08
                mov     al,ds:[tracks_per_buffer]            ; 0213: A0 36 05
                shl     al,1                                 ; 0216: D0 E0
                mov     ds:[tracks_per_buffer],al            ; 0218: A2 36 05

loc_021B:
                and     byte ptr ds:[copy_flags],3h          ; 021B: 80 26 38 05 03
                jmpn    copy_again                           ; 0220: E9 7A FF

; ---------------------------------------------------------------------------
; For one-drive copying, request the source diskette before the next batch.
; ---------------------------------------------------------------------------

prompt_source_if_needed:
                test    byte ptr ds:[copy_flags],1h          ; 0223: F6 06 38 05 01
                jz      loc_01B8                             ; 0228: 74 8E
                call    prompt_source                        ; 022A: E8 02 00
                jmp     short loc_01B8                       ; 022D: EB 89

; ---------------------------------------------------------------------------
; Display source insertion prompt; continue at the common prompt code.
; ---------------------------------------------------------------------------

prompt_source:
                mov     dx,data_057F                         ; 022F: BA 7F 05
                jmp     short loc_0237                       ; 0232: EB 03

; ---------------------------------------------------------------------------
; Display target insertion prompt, then wait for a fresh keypress.
; ---------------------------------------------------------------------------

prompt_target:
                mov     dx,data_05A6                         ; 0234: BA A6 05

loc_0237:
                mov     ah,9h                                ; 0237: B4 09
                int     21h                                  ; 0239: CD 21
                mov     dx,data_05CD                         ; 023B: BA CD 05
                int     21h                                  ; 023E: CD 21

; ---------------------------------------------------------------------------
; DOS AH=0Ch / AL=01h: flush keyboard input and read a key with echo.
; ---------------------------------------------------------------------------

wait_key:
                mov     ah,0Ch                               ; 0240: B4 0C
                mov     al,1h                                ; 0242: B0 01
                int     21h                                  ; 0244: CD 21
                ret                                          ; 0246: C3

; ---------------------------------------------------------------------------
; Read source tracks through BIOS INT 13h; detect one or two sides and retry errors.
; ---------------------------------------------------------------------------

read_source_tracks:
                and     byte ptr ds:[copy_flags],0F7h        ; 0247: 80 26 38 05 F7
                mov     byte ptr ds:[read_retries],0h        ; 024C: C6 06 39 05 00
                mov     dl,ds:[fcb1_drive]                   ; 0251: 8A 16 5C 00
                xor     dh,dh                                ; 0255: 32 F6
                mov     cl,1h                                ; 0257: B1 01
                mov     ch,ds:[current_track]                ; 0259: 8A 2E 35 05
                add     ch,ds:[tracks_per_buffer]            ; 025D: 02 2E 36 05
                mov     ds:[end_track],ch                    ; 0261: 88 2E 37 05
                sub     ch,ds:[tracks_per_buffer]            ; 0265: 2A 2E 36 05
                mov     es,word ptr ds:[buffer_segment]      ; 0269: 8E 06 3E 05
                mov     bp,es                                ; 026D: 8C C5
                rawop   82h,3Eh,37h,5h,28h                   ; 026F: 82 3E 37 05 28 ; cmp byte ptr ds:[end_track],28h
                jna     loc_027B                             ; 0274: 76 05
                mov     byte ptr ds:[end_track],28h          ; 0276: C6 06 37 05 28

loc_027B:
                xor     bx,bx                                ; 027B: 33 DB
                mov     ax,208h                              ; 027D: B8 08 02
                int     13h                                  ; 0280: CD 13
                jc      loc_02D2                             ; 0282: 72 4E

loc_0284:
                mov     byte ptr ds:[read_retries],0h        ; 0284: C6 06 39 05 00
                test    byte ptr ds:[copy_flags],10h         ; 0289: F6 06 38 05 10
                jnz     loc_02BB                             ; 028E: 75 2B
                test    byte ptr ds:[copy_flags],2h          ; 0290: F6 06 38 05 02
                jnz     loc_0308                             ; 0295: 75 71
                or      ch,ch                                ; 0297: 0A ED
                jnz     loc_02BB                             ; 0299: 75 20
                rawop   82h,0FEh,1h                          ; 029B: 82 FE 01 ; cmp dh,1h
                jnz     loc_02BB                             ; 029E: 75 1B
                or      byte ptr ds:[copy_flags],50h         ; 02A0: 80 0E 38 05 50
                mov     ah,ds:[tracks_per_buffer]            ; 02A5: 8A 26 36 05
                shr     ah,1                                 ; 02A9: D0 EC
                mov     ds:[tracks_per_buffer],ah            ; 02AB: 88 26 36 05
                mov     ds:[end_track],ah                    ; 02AF: 88 26 37 05
                mov     byte ptr ds:[data_0753],32h          ; 02B3: C6 06 53 07 32
                call    show_sides                           ; 02B8: E8 72 00

loc_02BB:
                add     bp,100h                              ; 02BB: 81 C5 00 01
                mov     es,bp                                ; 02BF: 8E C5
                xchg    dh,ds:[other_side]                   ; 02C1: 86 36 3D 05
                or      dh,dh                                ; 02C5: 0A F6
                jnz     loc_027B                             ; 02C7: 75 B2
                inc     ch                                   ; 02C9: FE C5
                cmp     ch,ds:[end_track]                    ; 02CB: 3A 2E 37 05
                jnz     loc_027B                             ; 02CF: 75 AA
                ret                                          ; 02D1: C3

loc_02D2:
                push    ax                                   ; 02D2: 50
                xor     ax,ax                                ; 02D3: 33 C0
                int     13h                                  ; 02D5: CD 13
                pop     ax                                   ; 02D7: 58
                cmp     ah,80h                               ; 02D8: 80 FC 80
                jz      loc_0327                             ; 02DB: 74 4A
                inc     byte ptr ds:[read_retries]           ; 02DD: FE 06 39 05
                rawop   82h,3Eh,39h,5h,4h                    ; 02E1: 82 3E 39 05 04 ; cmp byte ptr ds:[read_retries],4h
                jnz     loc_027B                             ; 02E6: 75 93
                test    byte ptr ds:[copy_flags],10h         ; 02E8: F6 06 38 05 10
                jnz     loc_031E                             ; 02ED: 75 2F
                or      ch,ch                                ; 02EF: 0A ED
                jnz     loc_031E                             ; 02F1: 75 2B
                rawop   82h,0FEh,1h                          ; 02F3: 82 FE 01 ; cmp dh,1h
                jnz     loc_031E                             ; 02F6: 75 26
                rawop   82h,0FCh,2h                          ; 02F8: 82 FC 02 ; cmp ah,2h
                jz      loc_0302                             ; 02FB: 74 05
                rawop   82h,0FCh,4h                          ; 02FD: 82 FC 04 ; cmp ah,4h
                jnz     loc_031E                             ; 0300: 75 1C

loc_0302:
                sub     bp,100h                              ; 0302: 81 ED 00 01
                mov     es,bp                                ; 0306: 8E C5

loc_0308:
                or      byte ptr ds:[copy_flags],10h         ; 0308: 80 0E 38 05 10
                xor     dh,dh                                ; 030D: 32 F6
                mov     byte ptr ds:[read_retries],0h        ; 030F: C6 06 39 05 00
                mov     byte ptr ds:[data_0753],31h          ; 0314: C6 06 53 07 31
                call    show_sides                           ; 0319: E8 11 00
                jmp     short loc_02BB                       ; 031C: EB 9D

loc_031E:
                mov     ax,5FDh                              ; 031E: B8 FD 05
                call    report_disk_error                    ; 0321: E8 97 01
                jmpn    loc_0284                             ; 0324: E9 5D FF

loc_0327:
                call    handle_not_ready                     ; 0327: E8 DC 01
                jmpn    loc_027B                             ; 032A: E9 4E FF

; ---------------------------------------------------------------------------
; Print the current one/two-side status message; preserve DX.
; ---------------------------------------------------------------------------

show_sides:
                push    dx                                   ; 032D: 52
                mov     dx,data_0749                         ; 032E: BA 49 07
                mov     ah,9h                                ; 0331: B4 09
                int     21h                                  ; 0333: CD 21
                pop     dx                                   ; 0335: 5A
                ret                                          ; 0336: C3

; ---------------------------------------------------------------------------
; Write buffered tracks through INT 13h; format on demand and verify each track.
; ---------------------------------------------------------------------------

write_target_tracks:
                mov     dl,ds:[fcb1_name]                    ; 0337: 8A 16 5D 00
                xor     dh,dh                                ; 033B: 32 F6
                mov     cl,1h                                ; 033D: B1 01
                mov     ch,ds:[current_track]                ; 033F: 8A 2E 35 05
                mov     es,word ptr ds:[buffer_segment]      ; 0343: 8E 06 3E 05
                mov     bp,es                                ; 0347: 8C C5

loc_0349:
                mov     byte ptr ds:[write_retries],0h       ; 0349: C6 06 3A 05 00
                mov     byte ptr ds:[verify_retries],0h      ; 034E: C6 06 3B 05 00
                test    byte ptr ds:[copy_flags],80h         ; 0353: F6 06 38 05 80
                jz      loc_0361                             ; 0358: 74 07
                or      dh,dh                                ; 035A: 0A F6
                jnz     loc_0361                             ; 035C: 75 03
                call    format_target_track                  ; 035E: E8 E8 00

loc_0361:
                or      byte ptr ds:[copy_flags],8h          ; 0361: 80 0E 38 05 08
                xor     bx,bx                                ; 0366: 33 DB
                mov     ax,308h                              ; 0368: B8 08 03
                int     13h                                  ; 036B: CD 13
                jc      loc_0398                             ; 036D: 72 29
                call    verify_target_track                  ; 036F: E8 9E 00
                rawop   82h,3Eh,3Bh,5h,0h                    ; 0372: 82 3E 3B 05 00 ; cmp byte ptr ds:[verify_retries],0h
                jnz     loc_0361                             ; 0377: 75 E8

loc_0379:
                xchg    dh,ds:[other_side]                   ; 0379: 86 36 3D 05
                or      dh,dh                                ; 037D: 0A F6
                jnz     loc_0383                             ; 037F: 75 02
                inc     ch                                   ; 0381: FE C5

loc_0383:
                add     bp,100h                              ; 0383: 81 C5 00 01
                mov     es,bp                                ; 0387: 8E C5
                cmp     ch,ds:[end_track]                    ; 0389: 3A 2E 37 05
                jnz     loc_0349                             ; 038D: 75 BA
                mov     ah,ds:[end_track]                    ; 038F: 8A 26 37 05
                mov     ds:[current_track],ah                ; 0393: 88 26 35 05
                ret                                          ; 0397: C3

loc_0398:
                push    ax                                   ; 0398: 50
                xor     ax,ax                                ; 0399: 33 C0
                int     13h                                  ; 039B: CD 13
                pop     ax                                   ; 039D: 58
                cmp     ah,80h                               ; 039E: 80 FC 80
                jz      loc_03EB                             ; 03A1: 74 48
                rawop   82h,0FCh,3h                          ; 03A3: 82 FC 03 ; cmp ah,3h
                jz      loc_03F1                             ; 03A6: 74 49
                inc     byte ptr ds:[write_retries]          ; 03A8: FE 06 3A 05
                rawop   82h,3Eh,3Ah,5h,4h                    ; 03AC: 82 3E 3A 05 04 ; cmp byte ptr ds:[write_retries],4h
                jnz     loc_0361                             ; 03B1: 75 AE
                rawop   82h,0FCh,2h                          ; 03B3: 82 FC 02 ; cmp ah,2h
                jz      loc_03BD                             ; 03B6: 74 05
                rawop   82h,0FCh,4h                          ; 03B8: 82 FC 04 ; cmp ah,4h
                jnz     loc_03E3                             ; 03BB: 75 26

loc_03BD:
                test    byte ptr ds:[copy_flags],80h         ; 03BD: F6 06 38 05 80
                jnz     loc_03FA                             ; 03C2: 75 36
                or      byte ptr ds:[copy_flags],80h         ; 03C4: 80 0E 38 05 80
                mov     ax,562h                              ; 03C9: B8 62 05
                call    report_disk_error                    ; 03CC: E8 EC 00
                or      dh,dh                                ; 03CF: 0A F6
                jnz     loc_03D6                             ; 03D1: 75 03
                jmpn    loc_0349                             ; 03D3: E9 73 FF

loc_03D6:
                sub     bp,100h                              ; 03D6: 81 ED 00 01
                mov     es,bp                                ; 03DA: 8E C5
                xchg    dh,ds:[other_side]                   ; 03DC: 86 36 3D 05
                jmpn    loc_0349                             ; 03E0: E9 66 FF

loc_03E3:
                mov     ax,622h                              ; 03E3: B8 22 06
                call    report_disk_error                    ; 03E6: E8 D2 00
                jmp     short loc_0379                       ; 03E9: EB 8E

loc_03EB:
                call    handle_not_ready                     ; 03EB: E8 18 01
                jmpn    loc_0361                             ; 03EE: E9 70 FF

loc_03F1:
                mov     ax,6EEh                              ; 03F1: B8 EE 06
                call    report_disk_error                    ; 03F4: E8 C4 00
                jmpn    loc_0361                             ; 03F7: E9 67 FF

loc_03FA:
                or      ch,ch                                ; 03FA: 0A ED
                jnz     loc_03E3                             ; 03FC: 75 E5
                rawop   82h,0FEh,1h                          ; 03FE: 82 FE 01 ; cmp dh,1h
                jnz     loc_03E3                             ; 0401: 75 E0
                mov     dx,data_075F                         ; 0403: BA 5F 07
                mov     ah,9h                                ; 0406: B4 09
                int     21h                                  ; 0408: CD 21
                mov     dx,data_06D2                         ; 040A: BA D2 06
                jmpn    loc_01DC                             ; 040D: E9 CC FD

; ---------------------------------------------------------------------------
; BIOS verify (AH=04h), with retry and not-ready handling.
; ---------------------------------------------------------------------------

verify_target_track:
                and     byte ptr ds:[copy_flags],0F7h        ; 0410: 80 26 38 05 F7
                xor     bx,bx                                ; 0415: 33 DB
                mov     ax,408h                              ; 0417: B8 08 04
                int     13h                                  ; 041A: CD 13
                jc      loc_0424                             ; 041C: 72 06
                mov     byte ptr ds:[verify_retries],0h      ; 041E: C6 06 3B 05 00

loc_0423:
                ret                                          ; 0423: C3

loc_0424:
                push    ax                                   ; 0424: 50
                xor     ax,ax                                ; 0425: 33 C0
                int     13h                                  ; 0427: CD 13
                pop     ax                                   ; 0429: 58
                cmp     ah,80h                               ; 042A: 80 FC 80
                jz      loc_0444                             ; 042D: 74 15
                inc     byte ptr ds:[verify_retries]         ; 042F: FE 06 3B 05
                rawop   82h,3Eh,3Bh,5h,4h                    ; 0433: 82 3E 3B 05 04 ; cmp byte ptr ds:[verify_retries],4h
                jnz     loc_0423                             ; 0438: 75 E9
                mov     ax,648h                              ; 043A: B8 48 06
                call    report_disk_error                    ; 043D: E8 7B 00
                pop     ax                                   ; 0440: 58
                jmpn    loc_0379                             ; 0441: E9 35 FF

loc_0444:
                call    handle_not_ready                     ; 0444: E8 BF 00
                jmp     short verify_target_track            ; 0447: EB C7

; ---------------------------------------------------------------------------
; Build cylinder/head fields in the sector-ID table and call BIOS format (AH=05h).
; ---------------------------------------------------------------------------

format_target_track:
                or      byte ptr ds:[copy_flags],8h          ; 0449: 80 0E 38 05 08
                push    es                                   ; 044E: 06
                push    cs                                   ; 044F: 0E
                pop     es                                   ; 0450: 07
                push    dx                                   ; 0451: 52
                mov     byte ptr ds:[format_retries],0h      ; 0452: C6 06 3C 05 00
                mov     al,ch                                ; 0457: 8A C5
                mov     ah,1h                                ; 0459: B4 01
                test    byte ptr ds:[copy_flags],40h         ; 045B: F6 06 38 05 40
                jnz     loc_0464                             ; 0460: 75 02
                dec     ah                                   ; 0462: FE CC

loc_0464:
                mov     dh,ah                                ; 0464: 8A F4
                mov     bx,buffer_segment                    ; 0466: BB 3E 05

loc_0469:
                add     bx,4h                                ; 0469: 83 C3 04
                mov     [bx],ax                              ; 046C: 89 07
                rawop   82h,7Fh,2h,8h                        ; 046E: 82 7F 02 08 ; cmp byte ptr [bx+2h],8h
                jnz     loc_0469                             ; 0472: 75 F5

loc_0474:
                mov     bx,format_id_table                   ; 0474: BB 42 05
                mov     ax,508h                              ; 0477: B8 08 05
                int     13h                                  ; 047A: CD 13
                jc      loc_048D                             ; 047C: 72 0F
                mov     byte ptr ds:[format_retries],0h      ; 047E: C6 06 3C 05 00
                mov     ax,ds:[format_id_table]              ; 0483: A1 42 05
                dec     ah                                   ; 0486: FE CC
                jz      loc_0464                             ; 0488: 74 DA
                pop     dx                                   ; 048A: 5A
                pop     es                                   ; 048B: 07
                ret                                          ; 048C: C3

loc_048D:
                push    ax                                   ; 048D: 50
                xor     ax,ax                                ; 048E: 33 C0
                int     13h                                  ; 0490: CD 13
                pop     ax                                   ; 0492: 58
                cmp     ah,80h                               ; 0493: 80 FC 80
                jz      loc_04AE                             ; 0496: 74 16
                rawop   82h,0FCh,3h                          ; 0498: 82 FC 03 ; cmp ah,3h
                jz      loc_04B3                             ; 049B: 74 16
                inc     byte ptr ds:[format_retries]         ; 049D: FE 06 3C 05
                rawop   82h,3Eh,3Ch,5h,4h                    ; 04A1: 82 3E 3C 05 04 ; cmp byte ptr ds:[format_retries],4h
                jnz     loc_0474                             ; 04A6: 75 CC
                mov     dx,data_06AA                         ; 04A8: BA AA 06
                jmpn    loc_01DC                             ; 04AB: E9 2E FD

loc_04AE:
                call    handle_not_ready                     ; 04AE: E8 55 00
                jmp     short loc_0474                       ; 04B1: EB C1

loc_04B3:
                mov     ax,6EEh                              ; 04B3: B8 EE 06
                call    report_disk_error                    ; 04B6: E8 02 00
                jmp     short loc_0474                       ; 04B9: EB B9

; ---------------------------------------------------------------------------
; AX=message, CH=track, DH=side. Print error and track/side context; preserve DX.
; ---------------------------------------------------------------------------

report_disk_error:
                push    dx                                   ; 04BB: 52
                mov     ds:[data_0680],dh                    ; 04BC: 88 36 80 06
                or      byte ptr ds:[data_0680],30h          ; 04C0: 80 0E 80 06 30
                mov     dx,ax                                ; 04C5: 8B D0
                mov     ah,9h                                ; 04C7: B4 09
                int     21h                                  ; 04C9: CD 21
                cmp     dx,6EEh                              ; 04CB: 81 FA EE 06
                jz      loc_04FF                             ; 04CF: 74 2E
                cmp     dx,562h                              ; 04D1: 81 FA 62 05
                jz      loc_04FD                             ; 04D5: 74 26
                mov     word ptr ds:[data_0677],3030h        ; 04D7: C7 06 77 06 30 30
                mov     ah,ch                                ; 04DD: 8A E5

loc_04DF:
                rawop   82h,0FCh,0Ah                         ; 04DF: 82 FC 0A ; cmp ah,0Ah
                jc      loc_04ED                             ; 04E2: 72 09
                inc     byte ptr ds:[data_0677]              ; 04E4: FE 06 77 06
                rawop   82h,0ECh,0Ah                         ; 04E8: 82 EC 0A ; sub ah,0Ah
                jmp     short loc_04DF                       ; 04EB: EB F2

loc_04ED:
                or      ds:[data_0678],ah                    ; 04ED: 08 26 78 06
                mov     dx,data_066F                         ; 04F1: BA 6F 06
                mov     ah,9h                                ; 04F4: B4 09
                int     21h                                  ; 04F6: CD 21
                or      byte ptr ds:[copy_flags],20h         ; 04F8: 80 0E 38 05 20

loc_04FD:
                pop     dx                                   ; 04FD: 5A
                ret                                          ; 04FE: C3

loc_04FF:
                mov     ax,0C01h                             ; 04FF: B8 01 0C
                int     21h                                  ; 0502: CD 21
                pop     dx                                   ; 0504: 5A
                ret                                          ; 0505: C3

; ---------------------------------------------------------------------------
; DL=drive. Request correction of a not-ready error and wait for a key; preserve DX.
; ---------------------------------------------------------------------------

handle_not_ready:
                push    dx                                   ; 0506: 52
                rawop   82h,0C2h,41h                         ; 0507: 82 C2 41 ; add dl,41h
                mov     ds:[data_07A7],dl                    ; 050A: 88 16 A7 07
                mov     dx,data_077D                         ; 050E: BA 7D 07
                mov     ah,9h                                ; 0511: B4 09
                int     21h                                  ; 0513: CD 21
                mov     dx,data_0790                         ; 0515: BA 90 07
                test    byte ptr ds:[copy_flags],8h          ; 0518: F6 06 38 05 08
                jz      loc_0522                             ; 051D: 74 03
                mov     dx,data_0798                         ; 051F: BA 98 07

loc_0522:
                int     21h                                  ; 0522: CD 21
                mov     dx,data_07A0                         ; 0524: BA A0 07
                int     21h                                  ; 0527: CD 21
                mov     dx,data_0711                         ; 0529: BA 11 07
                int     21h                                  ; 052C: CD 21
                mov     ax,0C01h                             ; 052E: B8 01 0C
                int     21h                                  ; 0531: CD 21
                pop     dx                                   ; 0533: 5A
                ret                                          ; 0534: C3

; current_track (0535h)
                db      0h                                    ; 0535: 00

; tracks_per_buffer (0536h)
                db      0h                                    ; 0536: 00

; end_track (0537h)
                db      0h                                    ; 0537: 00

; copy_flags (0538h)
                db      0h                                    ; 0538: 00

; read_retries (0539h)
                db      0h                                    ; 0539: 00

; write_retries (053Ah)
                db      0h                                    ; 053A: 00

; verify_retries (053Bh)
                db      0h                                    ; 053B: 00

; format_retries (053Ch)
                db      0h                                    ; 053C: 00

; other_side (053Dh)
                db      0h                                    ; 053D: 00

; buffer_segment (053Eh)
                db      0h,0h,0h,1h                           ; 053E: 00 00 00 01

; format_id_table (0542h)
                db      0h,0h,1h,2h,0h,0h,2h,2h,0h,0h,3h,2h   ; 0542: 00 00 01 02 00 00 02 02 00 00 03 02
                db      0h,0h,4h,2h,0h,0h,5h,2h,0h,0h,6h,2h   ; 054E: 00 00 04 02 00 00 05 02 00 00 06 02
                db      0h,0h,7h,2h,0h,0h,8h,2h,0Dh,0Ah       ; 055A: 00 00 07 02 00 00 08 02 0D 0A
                db      "Formatting while copying"            ; 0564: 24 data bytes
                db      0Dh,0Ah                               ; 057C: 0D 0A
                db      "$"                                   ; 057E: 24

; data_057F (057Fh)
                db      0Dh,0Ah                               ; 057F: 0D 0A
                db      "Insert source diskette in drive "    ; 0581: 32 data bytes

; data_05A1 (05A1h)
                db      "@:"                                  ; 05A1: 40 3A
                db      0Dh,0Ah                               ; 05A3: 0D 0A
                db      "$"                                   ; 05A5: 24

; data_05A6 (05A6h)
                db      0Dh,0Ah                               ; 05A6: 0D 0A
                db      "Insert target diskette in drive "    ; 05A8: 32 data bytes

; data_05C8 (05C8h)
                db      "@:"                                  ; 05C8: 40 3A
                db      0Dh,0Ah                               ; 05CA: 0D 0A
                db      "$"                                   ; 05CC: 24

; data_05CD (05CDh)
                db      0Dh,0Ah                               ; 05CD: 0D 0A
                db      "Strike any key when ready"           ; 05CF: 25 data bytes
                db      0Dh,0Ah                               ; 05E8: 0D 0A
                db      "$"                                   ; 05EA: 24

; data_05EB (05EBh)
                db      0Dh,0Ah                               ; 05EB: 0D 0A
                db      "Copy complete"                       ; 05ED: 13 data bytes
                db      0Dh,0Ah                               ; 05FA: 0D 0A
                db      "$"                                   ; 05FC: 24
                db      0Dh,0Ah                               ; 05FD: 0D 0A
                db      "Unrecoverable read error on source$" ; 05FF: 35 data bytes
                db      0Dh,0Ah                               ; 0622: 0D 0A
                db      "Unrecoverable write error on target$"; 0624: 36 data bytes
                db      0Dh,0Ah                               ; 0648: 0D 0A
                db      "Unrecoverable verify error on target$"; 064A: 37 data bytes

; data_066F (066Fh)
                db      0Dh,0Ah                               ; 066F: 0D 0A
                db      "Track "                              ; 0671: 54 72 61 63 6B 20

; data_0677 (0677h)
                db      "0"                                   ; 0677: 30

; data_0678 (0678h)
                db      "0, side "                            ; 0678: 30 2C 20 73 69 64 65 20

; data_0680 (0680h)
                db      "0"                                   ; 0680: 30
                db      7h,0Dh,0Ah                            ; 0681: 07 0D 0A
                db      "$"                                   ; 0684: 24

; data_0685 (0685h)
                db      0Dh,0Ah                               ; 0685: 0D 0A
                db      "Target diskette may be unusable"     ; 0687: 31 data bytes
                db      7h,0Dh,0Ah                            ; 06A6: 07 0D 0A
                db      "$"                                   ; 06A9: 24

; data_06AA (06AAh)
                db      0Dh,0Ah                               ; 06AA: 0D 0A
                db      "Unrecoverable format error on target"; 06AC: 36 data bytes
                db      0Dh,0Ah                               ; 06D0: 0D 0A

; data_06D2 (06D2h)
                db      "Target diskette unusable"            ; 06D2: 24 data bytes
                db      7h,0Dh,0Ah                            ; 06EA: 07 0D 0A
                db      "$"                                   ; 06ED: 24
                db      0Dh,0Ah                               ; 06EE: 0D 0A
                db      "Target diskette write protected"     ; 06F0: 31 data bytes
                db      0Dh,0Ah                               ; 070F: 0D 0A

; data_0711 (0711h)
                db      0Dh,0Ah                               ; 0711: 0D 0A
                db      "Correct, then strike any key"        ; 0713: 28 data bytes
                db      7h,0Dh,0Ah                            ; 072F: 07 0D 0A
                db      "$"                                   ; 0732: 24

; data_0733 (0733h)
                db      0Dh,0Ah                               ; 0733: 0D 0A
                db      "Copy another (Y/N)?$"                ; 0735: 20 data bytes

; data_0749 (0749h)
                db      0Dh,0Ah                               ; 0749: 0D 0A
                db      "Copying "                            ; 074B: 43 6F 70 79 69 6E 67 20

; data_0753 (0753h)
                db      0h                                    ; 0753: 00
                db      " side(s)"                            ; 0754: 20 73 69 64 65 28 73 29
                db      0Dh,0Ah                               ; 075C: 0D 0A
                db      "$"                                   ; 075E: 24

; data_075F (075Fh)
                db      0Dh,0Ah                               ; 075F: 0D 0A
                db      "Incompatible drive types"            ; 0761: 24 data bytes
                db      0Dh,0Ah,7h                            ; 0779: 0D 0A 07
                db      "$"                                   ; 077C: 24

; data_077D (077Dh)
                db      0Dh,0Ah                               ; 077D: 0D 0A
                db      "Not ready error $"                   ; 077F: 17 data bytes

; data_0790 (0790h)
                db      "reading$"                            ; 0790: 72 65 61 64 69 6E 67 24

; data_0798 (0798h)
                db      "writing$"                            ; 0798: 77 72 69 74 69 6E 67 24

; data_07A0 (07A0h)
                db      " drive "                             ; 07A0: 20 64 72 69 76 65 20

; data_07A7 (07A7h)
                db      0h,0Dh,0Ah                            ; 07A7: 00 0D 0A
                db      "$"                                   ; 07AA: 24
                db      0h                                    ; 07AB: 00

; ---------------------------------------------------------------------------
; Initialize drive selection and buffer allocation; parse the /1 option.
; ---------------------------------------------------------------------------

init:
                cld                                          ; 07AC: FC
                mov     sp,100h                              ; 07AD: BC 00 01
                xor     dx,dx                                ; 07B0: 33 D2
                push    dx                                   ; 07B2: 52
                or      ah,al                                ; 07B3: 0A E0
                rawop   82h,0FCh,0FFh                        ; 07B5: 82 FC FF ; cmp ah,0FFh
                jz      loc_0802                             ; 07B8: 74 48
                mov     dx,data_08A0                         ; 07BA: BA A0 08
                rawop   82h,3Eh,5Dh,0h,20h                   ; 07BD: 82 3E 5D 00 20 ; cmp byte ptr ds:[fcb1_name],20h
                jnz     loc_0805                             ; 07C2: 75 41
                rawop   82h,3Eh,6Dh,0h,20h                   ; 07C4: 82 3E 6D 00 20 ; cmp byte ptr ds:[fcb2_name],20h
                jnz     loc_0805                             ; 07C9: 75 3A
                mov     ah,ds:[fcb2_drive]                   ; 07CB: 8A 26 6C 00
                mov     ds:[fcb1_name],ah                    ; 07CF: 88 26 5D 00
                int     11h                                  ; 07D3: CD 11
                mov     cl,6h                                ; 07D5: B1 06
                shr     al,cl                                ; 07D7: D2 E8
                and     al,3h                                ; 07D9: 24 03
                inc     al                                   ; 07DB: FE C0
                mov     bl,al                                ; 07DD: 8A D8
                mov     ah,19h                               ; 07DF: B4 19
                int     21h                                  ; 07E1: CD 21
                inc     al                                   ; 07E3: FE C0
                rawop   82h,0FBh,1h                          ; 07E5: 82 FB 01 ; cmp bl,1h
                jnz     loc_07F6                             ; 07E8: 75 0C
                mov     byte ptr ds:[fcb1_drive],1h          ; 07EA: C6 06 5C 00 01
                mov     byte ptr ds:[fcb1_name],1h           ; 07EF: C6 06 5D 00 01
                jmp     short loc_0815                       ; 07F4: EB 1F

loc_07F6:
                test    byte ptr ds:[fcb1_drive],0FFh        ; 07F6: F6 06 5C 00 FF
                jnz     loc_080B                             ; 07FB: 75 0E
                mov     ds:[fcb1_drive],al                   ; 07FD: A2 5C 00
                jmp     short loc_080B                       ; 0800: EB 09

loc_0802:
                mov     dx,data_08B7                         ; 0802: BA B7 08

loc_0805:
                mov     ah,9h                                ; 0805: B4 09
                int     21h                                  ; 0807: CD 21
                int     20h                                  ; 0809: CD 20

loc_080B:
                test    byte ptr ds:[fcb1_name],0FFh         ; 080B: F6 06 5D 00 FF
                jnz     loc_0815                             ; 0810: 75 03
                mov     ds:[fcb1_name],al                    ; 0812: A2 5D 00

loc_0815:
                mov     al,ds:[fcb1_drive]                   ; 0815: A0 5C 00
                or      ds:[data_05A1],al                    ; 0818: 08 06 A1 05
                dec     al                                   ; 081C: FE C8
                mov     ds:[fcb1_drive],al                   ; 081E: A2 5C 00
                mov     ah,al                                ; 0821: 8A E0
                mov     al,ds:[fcb1_name]                    ; 0823: A0 5D 00
                or      ds:[data_05C8],al                    ; 0826: 08 06 C8 05
                dec     al                                   ; 082A: FE C8
                mov     ds:[fcb1_name],al                    ; 082C: A2 5D 00
                cmp     al,ah                                ; 082F: 3A C4
                jnz     loc_0838                             ; 0831: 75 05
                or      byte ptr ds:[copy_flags],1h          ; 0833: 80 0E 38 05 01

loc_0838:
                mov     byte ptr ds:[other_side],1h          ; 0838: C6 06 3D 05 01
                mov     dx,offset init                       ; 083D: BA AC 07
                mov     cl,4h                                ; 0840: B1 04
                shr     dx,cl                                ; 0842: D3 EA
                mov     ax,cs                                ; 0844: 8C C8
                add     dx,ax                                ; 0846: 03 D0
                xor     dl,dl                                ; 0848: 32 D2
                inc     dh                                   ; 084A: FE C6
                mov     ds:[buffer_segment],dx               ; 084C: 89 16 3E 05
                mov     ax,ds:[psp_end_segment]              ; 0850: A1 02 00
                sub     ax,dx                                ; 0853: 2B C2
                mov     cl,8h                                ; 0855: B1 08
                shr     ax,cl                                ; 0857: D3 E8
                mov     dx,data_0887                         ; 0859: BA 87 08
                cmp     ax,2h                                ; 085C: 3D 02 00
                jc      loc_0805                             ; 085F: 72 A4
                mov     ds:[tracks_per_buffer],al            ; 0861: A2 36 05
                xor     ch,ch                                ; 0864: 32 ED
                mov     cl,ds:[command_length]               ; 0866: 8A 0E 80 00
                jcxz    loc_0884                             ; 086A: E3 18
                mov     di,81h                               ; 086C: BF 81 00
                mov     al,2Fh                               ; 086F: B0 2F
                repne   scasb                                ; 0871: F2 AE
                jnz     loc_0884                             ; 0873: 75 0F
                rawop   82h,3Dh,31h                          ; 0875: 82 3D 31 ; cmp byte ptr [di],31h
                jnz     loc_0884                             ; 0878: 75 0A
                or      byte ptr ds:[copy_flags],2h          ; 087A: 80 0E 38 05 02
                mov     byte ptr ds:[other_side],0h          ; 087F: C6 06 3D 05 00

loc_0884:
                jmpn    copy_again                           ; 0884: E9 16 F9

; data_0887 (0887h)
                db      0Dh,0Ah                               ; 0887: 0D 0A
                db      "Insufficient memory"                 ; 0889: 19 data bytes
                db      7h,0Dh,0Ah                            ; 089C: 07 0D 0A
                db      "$"                                   ; 089F: 24

; data_08A0 (08A0h)
                db      0Dh,0Ah                               ; 08A0: 0D 0A
                db      "Invalid parameter"                   ; 08A2: 17 data bytes
                db      7h,0Dh,0Ah                            ; 08B3: 07 0D 0A
                db      "$"                                   ; 08B6: 24

; data_08B7 (08B7h)
                db      0Dh,0Ah                               ; 08B7: 0D 0A
                db      "Invalid drive specification"         ; 08B9: 27 data bytes
                db      7h,0Dh,0Ah                            ; 08D4: 07 0D 0A
                db      "$"                                   ; 08D7: 24

program         ends
                end     start
