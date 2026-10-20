;*-------------------------------------------------------------------------
;  DISKCOMP.ASM - PC DOS 1.10 Diskette Compare Utility
;
;  Build: make diskcomp.com     Verify: make check-utilities
;  Original: bin/diskcomp.com, 1640 bytes; COM load address 0100h.
;  Each emitted line records its COM address and original bytes.
;  File offset = COM address - 0100h. Numeric loc_ / data_ names retain
;  addresses where a fuller semantic name has not yet been established.
;  This is an exact static mapping; runtime behavior has not been tested.
;
;  Layout:
;    0100h-0102h  code
;    01A6h-048Ah  code
;    0619h-0716h  code
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
read_buffer_segment     equ     48Bh
compare_buffer_segment  equ     48Dh
second_buffer_segment   equ     48Fh
second_buffer_offset    equ     491h
current_track           equ     493h
other_side              equ     494h
tracks_per_buffer       equ     495h
end_track               equ     496h
compare_flags           equ     497h
read_retries            equ     498h
second_read_count       equ     499h
buffer_end_track        equ     49Ah
data_049B               equ     49Bh
data_04BC               equ     4BCh
data_04C1               equ     4C1h
data_04E3               equ     4E3h
data_04E8               equ     4E8h
data_0506               equ     506h
data_051F               equ     51Fh
data_0543               equ     543h
data_0547               equ     547h
data_054D               equ     54Dh
data_054E               equ     54Eh
data_0556               equ     556h
data_055B               equ     55Bh
data_0574               equ     574h
data_0594               equ     594h
data_05A0               equ     5A0h
data_05AC               equ     5ACh
data_05D6               equ     5D6h
data_05F7               equ     5F7h
data_0717               equ     717h
data_0738               equ     738h
data_0751               equ     751h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; COM entry point. DOS supplies the PSP and parsed default FCBs.
; ---------------------------------------------------------------------------

start:
                jmpn    init                                 ; 0100: E9 16 05
                db      "The IBM Personal Computer Diskette Compa"; 0103: 40 data bytes
                db      "re Utility Version 1.10 (C)Copyright IBM"; 012B: 40 data bytes
                db      " Corp 1981, 1982 Licensed Material - Pro"; 0153: 40 data bytes
                db      "gram Property of IBM Author - David Litt"; 017B: 40 data bytes
                db      "on "                                 ; 01A3: 6F 6E 20

; ---------------------------------------------------------------------------
; Read both diskettes in buffered batches and report track/side mismatches.
; ---------------------------------------------------------------------------

compare_again:
                mov     dx,data_049B                         ; 01A6: BA 9B 04
                mov     ah,9h                                ; 01A9: B4 09
                int     21h                                  ; 01AB: CD 21
                test    byte ptr ds:[compare_flags],1h       ; 01AD: F6 06 97 04 01
                jz      loc_01BF                             ; 01B2: 74 0B
                mov     dx,data_04E8                         ; 01B4: BA E8 04
                int     21h                                  ; 01B7: CD 21
                call    wait_key                             ; 01B9: E8 FC 00
                jmpn    loc_01C2                             ; 01BC: E9 03 00

loc_01BF:
                call    prompt_second                        ; 01BF: E8 EA 00

loc_01C2:
                mov     es,word ptr ds:[read_buffer_segment] ; 01C2: 8E 06 8B 04
                mov     word ptr ds:[compare_buffer_segment],es; 01C6: 8C 06 8D 04
                mov     dl,ds:[fcb1_drive]                   ; 01CA: 8A 16 5C 00
                mov     dh,ds:[tracks_per_buffer]            ; 01CE: 8A 36 95 04
                call    read_tracks                          ; 01D2: E8 EA 00
                mov     ds:[buffer_end_track],ch             ; 01D5: 88 2E 9A 04
                test    byte ptr ds:[compare_flags],1h       ; 01D9: F6 06 97 04 01
                jz      loc_01E3                             ; 01DE: 74 03
                call    prompt_second                        ; 01E0: E8 C9 00

loc_01E3:
                mov     es,word ptr ds:[second_buffer_segment]; 01E3: 8E 06 8F 04
                mov     dl,ds:[fcb1_name]                    ; 01E7: 8A 16 5D 00
                mov     dh,ds:[second_read_count]            ; 01EB: 8A 36 99 04
                call    read_tracks                          ; 01EF: E8 CD 00
                call    compare_buffers                      ; 01F2: E8 11 02
                mov     ch,ds:[end_track]                    ; 01F5: 8A 2E 96 04
                rawop   82h,0FDh,28h                         ; 01F9: 82 FD 28 ; cmp ch,28h
                jz      loc_0251                             ; 01FC: 74 53
                mov     ds:[current_track],ch                ; 01FE: 88 2E 93 04
                cmp     ch,ds:[buffer_end_track]             ; 0202: 3A 2E 9A 04
                jnz     loc_01E3                             ; 0206: 75 DB
                mov     es,word ptr ds:[read_buffer_segment] ; 0208: 8E 06 8B 04
                mov     word ptr ds:[compare_buffer_segment],es; 020C: 8C 06 8D 04
                mov     dl,ds:[fcb1_name]                    ; 0210: 8A 16 5D 00
                mov     dh,ds:[tracks_per_buffer]            ; 0214: 8A 36 95 04
                call    read_tracks                          ; 0218: E8 A4 00
                mov     ds:[buffer_end_track],ch             ; 021B: 88 2E 9A 04
                test    byte ptr ds:[compare_flags],1h       ; 021F: F6 06 97 04 01
                jz      loc_0229                             ; 0224: 74 03
                call    prompt_first                         ; 0226: E8 7D 00

loc_0229:
                mov     es,word ptr ds:[second_buffer_segment]; 0229: 8E 06 8F 04
                mov     dl,ds:[fcb1_drive]                   ; 022D: 8A 16 5C 00
                mov     dh,ds:[second_read_count]            ; 0231: 8A 36 99 04
                call    read_tracks                          ; 0235: E8 87 00
                call    compare_buffers                      ; 0238: E8 CB 01
                mov     ch,ds:[end_track]                    ; 023B: 8A 2E 96 04
                rawop   82h,0FDh,28h                         ; 023F: 82 FD 28 ; cmp ch,28h
                jz      loc_0251                             ; 0242: 74 0D
                mov     ds:[current_track],ch                ; 0244: 88 2E 93 04
                cmp     ch,ds:[buffer_end_track]             ; 0248: 3A 2E 9A 04
                jnz     loc_0229                             ; 024C: 75 DB
                jmpn    loc_01C2                             ; 024E: E9 71 FF

loc_0251:
                test    byte ptr ds:[compare_flags],4h       ; 0251: F6 06 97 04 04
                jnz     loc_025F                             ; 0256: 75 07
                mov     dx,data_0506                         ; 0258: BA 06 05

loc_025B:
                mov     ah,9h                                ; 025B: B4 09
                int     21h                                  ; 025D: CD 21

loc_025F:
                mov     dx,data_0574                         ; 025F: BA 74 05
                mov     ah,9h                                ; 0262: B4 09
                int     21h                                  ; 0264: CD 21
                mov     ax,0C01h                             ; 0266: B8 01 0C
                int     21h                                  ; 0269: CD 21
                or      al,20h                               ; 026B: 0C 20
                cmp     al,6Eh                               ; 026D: 3C 6E
                jnz     loc_0273                             ; 026F: 75 02
                int     20h                                  ; 0271: CD 20

loc_0273:
                cmp     al,79h                               ; 0273: 3C 79
                jnz     loc_025F                             ; 0275: 75 E8
                mov     byte ptr ds:[current_track],0h       ; 0277: C6 06 93 04 00
                test    byte ptr ds:[compare_flags],2h       ; 027C: F6 06 97 04 02
                jnz     loc_029B                             ; 0281: 75 18
                mov     byte ptr ds:[other_side],1h          ; 0283: C6 06 94 04 01
                test    byte ptr ds:[compare_flags],40h      ; 0288: F6 06 97 04 40
                jz      loc_029B                             ; 028D: 74 0C
                mov     al,ds:[tracks_per_buffer]            ; 028F: A0 95 04
                shl     al,1                                 ; 0292: D0 E0
                mov     ds:[tracks_per_buffer],al            ; 0294: A2 95 04
                inc     byte ptr ds:[second_read_count]      ; 0297: FE 06 99 04

loc_029B:
                and     byte ptr ds:[compare_flags],3h       ; 029B: 80 26 97 04 03
                mov     sp,100h                              ; 02A0: BC 00 01
                jmpn    compare_again                        ; 02A3: E9 00 FF

; ---------------------------------------------------------------------------
; Display first diskette insertion prompt; enter common prompt code.
; ---------------------------------------------------------------------------

prompt_first:
                mov     dx,data_049B                         ; 02A6: BA 9B 04
                jmpn    loc_02AF                             ; 02A9: E9 03 00

; ---------------------------------------------------------------------------
; Display second diskette insertion prompt, then wait for a fresh keypress.
; ---------------------------------------------------------------------------

prompt_second:
                mov     dx,data_04C1                         ; 02AC: BA C1 04

loc_02AF:
                mov     ah,9h                                ; 02AF: B4 09
                int     21h                                  ; 02B1: CD 21
                mov     dx,data_04E8                         ; 02B3: BA E8 04
                int     21h                                  ; 02B6: CD 21

; ---------------------------------------------------------------------------
; DOS AH=0Ch / AL=01h: flush keyboard input and read a key with echo.
; ---------------------------------------------------------------------------

wait_key:
                mov     ah,0Ch                               ; 02B8: B4 0C
                mov     al,1h                                ; 02BA: B0 01
                int     21h                                  ; 02BC: CD 21
                ret                                          ; 02BE: C3

; ---------------------------------------------------------------------------
; ES=buffer, DL=drive, DH=track count. Read tracks and probe diskette geometry.
; ---------------------------------------------------------------------------

read_tracks:
                mov     byte ptr ds:[read_retries],0h        ; 02BF: C6 06 98 04 00
                mov     bp,es                                ; 02C4: 8C C5
                mov     cl,1h                                ; 02C6: B1 01
                mov     ch,ds:[current_track]                ; 02C8: 8A 2E 93 04
                add     ch,dh                                ; 02CC: 02 EE
                mov     ds:[end_track],ch                    ; 02CE: 88 2E 96 04
                sub     ch,dh                                ; 02D2: 2A EE
                xor     dh,dh                                ; 02D4: 32 F6
                rawop   82h,3Eh,96h,4h,28h                   ; 02D6: 82 3E 96 04 28 ; cmp byte ptr ds:[end_track],28h
                jna     loc_02E2                             ; 02DB: 76 05
                mov     byte ptr ds:[end_track],28h          ; 02DD: C6 06 96 04 28

loc_02E2:
                xor     bx,bx                                ; 02E2: 33 DB
                mov     ax,208h                              ; 02E4: B8 08 02
                int     13h                                  ; 02E7: CD 13
                jc      loc_0340                             ; 02E9: 72 55

loc_02EB:
                mov     byte ptr ds:[read_retries],0h        ; 02EB: C6 06 98 04 00
                test    byte ptr ds:[compare_flags],10h      ; 02F0: F6 06 97 04 10
                jnz     loc_0329                             ; 02F5: 75 32
                test    byte ptr ds:[compare_flags],2h       ; 02F7: F6 06 97 04 02
                jz      loc_0301                             ; 02FC: 74 03
                jmpn    loc_0392                             ; 02FE: E9 91 00

loc_0301:
                or      ch,ch                                ; 0301: 0A ED
                jnz     loc_0329                             ; 0303: 75 24
                rawop   82h,0FEh,1h                          ; 0305: 82 FE 01 ; cmp dh,1h
                jnz     loc_0329                             ; 0308: 75 1F
                or      byte ptr ds:[compare_flags],50h      ; 030A: 80 0E 97 04 50
                mov     ah,ds:[tracks_per_buffer]            ; 030F: 8A 26 95 04
                shr     ah,1                                 ; 0313: D0 EC
                mov     ds:[tracks_per_buffer],ah            ; 0315: 88 26 95 04
                mov     ds:[end_track],ah                    ; 0319: 88 26 96 04
                dec     byte ptr ds:[second_read_count]      ; 031D: FE 0E 99 04
                mov     byte ptr ds:[data_05A0],32h          ; 0321: C6 06 A0 05 32
                call    show_sides                           ; 0326: E8 D3 00

loc_0329:
                add     bp,100h                              ; 0329: 81 C5 00 01
                mov     es,bp                                ; 032D: 8E C5
                xchg    dh,ds:[other_side]                   ; 032F: 86 36 94 04
                or      dh,dh                                ; 0333: 0A F6
                jnz     loc_02E2                             ; 0335: 75 AB
                inc     ch                                   ; 0337: FE C5
                cmp     ch,ds:[end_track]                    ; 0339: 3A 2E 96 04
                jnz     loc_02E2                             ; 033D: 75 A3
                ret                                          ; 033F: C3

loc_0340:
                push    ax                                   ; 0340: 50
                xor     ax,ax                                ; 0341: 33 C0
                int     13h                                  ; 0343: CD 13
                pop     ax                                   ; 0345: 58
                cmp     ah,80h                               ; 0346: 80 FC 80
                jz      loc_0368                             ; 0349: 74 1D
                inc     byte ptr ds:[read_retries]           ; 034B: FE 06 98 04
                rawop   82h,3Eh,98h,4h,4h                    ; 034F: 82 3E 98 04 04 ; cmp byte ptr ds:[read_retries],4h
                jnz     loc_02E2                             ; 0354: 75 8C
                call    check_geometry_error                 ; 0356: E8 8C 00
                jnc     loc_03A8                             ; 0359: 73 4D
                test    byte ptr ds:[compare_flags],10h      ; 035B: F6 06 97 04 10
                jz      loc_038C                             ; 0360: 74 2A
                mov     dx,data_05AC                         ; 0362: BA AC 05
                jmpn    loc_025B                             ; 0365: E9 F3 FE

loc_0368:
                push    dx                                   ; 0368: 52
                mov     ds:[data_0543],dl                    ; 0369: 88 16 43 05
                rawop   82h,6h,43h,5h,41h                    ; 036D: 82 06 43 05 41 ; add byte ptr ds:[data_0543],41h
                mov     dx,data_05D6                         ; 0372: BA D6 05
                mov     ah,9h                                ; 0375: B4 09
                int     21h                                  ; 0377: CD 21
                mov     dx,data_0543                         ; 0379: BA 43 05
                int     21h                                  ; 037C: CD 21
                mov     dx,data_05F7                         ; 037E: BA F7 05
                int     21h                                  ; 0381: CD 21
                mov     ax,0C01h                             ; 0383: B8 01 0C
                int     21h                                  ; 0386: CD 21
                pop     dx                                   ; 0388: 5A
                jmpn    loc_02E2                             ; 0389: E9 56 FF

loc_038C:
                sub     bp,100h                              ; 038C: 81 ED 00 01
                mov     es,bp                                ; 0390: 8E C5

loc_0392:
                or      byte ptr ds:[compare_flags],10h      ; 0392: 80 0E 97 04 10
                xor     dh,dh                                ; 0397: 32 F6
                mov     byte ptr ds:[read_retries],0h        ; 0399: C6 06 98 04 00
                mov     byte ptr ds:[data_05A0],31h          ; 039E: C6 06 A0 05 31
                call    show_sides                           ; 03A3: E8 56 00
                jmp     short loc_0329                       ; 03A6: EB 81

loc_03A8:
                mov     ds:[data_0543],dl                    ; 03A8: 88 16 43 05
                rawop   82h,6h,43h,5h,41h                    ; 03AC: 82 06 43 05 41 ; add byte ptr ds:[data_0543],41h
                mov     ds:[data_0556],dh                    ; 03B1: 88 36 56 05
                or      byte ptr ds:[data_0556],30h          ; 03B5: 80 0E 56 05 30
                mov     word ptr ds:[data_054D],3030h        ; 03BA: C7 06 4D 05 30 30
                mov     ah,ch                                ; 03C0: 8A E5

loc_03C2:
                rawop   82h,0FCh,0Ah                         ; 03C2: 82 FC 0A ; cmp ah,0Ah
                jc      loc_03D0                             ; 03C5: 72 09
                inc     byte ptr ds:[data_054D]              ; 03C7: FE 06 4D 05
                rawop   82h,0ECh,0Ah                         ; 03CB: 82 EC 0A ; sub ah,0Ah
                jmp     short loc_03C2                       ; 03CE: EB F2

loc_03D0:
                or      ds:[data_054E],ah                    ; 03D0: 08 26 4E 05
                push    dx                                   ; 03D4: 52
                mov     dx,data_051F                         ; 03D5: BA 1F 05
                mov     ah,9h                                ; 03D8: B4 09
                int     21h                                  ; 03DA: CD 21
                mov     dx,data_0547                         ; 03DC: BA 47 05
                int     21h                                  ; 03DF: CD 21
                pop     dx                                   ; 03E1: 5A
                jmpn    loc_02EB                             ; 03E2: E9 06 FF

; ---------------------------------------------------------------------------
; CH=track, DH=side, AH=BIOS status. CF marks a possible single-sided diskette.
; ---------------------------------------------------------------------------

check_geometry_error:
                or      ch,ch                                ; 03E5: 0A ED
                jnz     loc_03FA                             ; 03E7: 75 11
                rawop   82h,0FEh,1h                          ; 03E9: 82 FE 01 ; cmp dh,1h
                jnz     loc_03FA                             ; 03EC: 75 0C
                rawop   82h,0FCh,2h                          ; 03EE: 82 FC 02 ; cmp ah,2h
                jz      loc_03F8                             ; 03F1: 74 05
                rawop   82h,0FCh,4h                          ; 03F3: 82 FC 04 ; cmp ah,4h
                jnz     loc_03FA                             ; 03F6: 75 02

loc_03F8:
                stc                                          ; 03F8: F9
                ret                                          ; 03F9: C3

loc_03FA:
                clc                                          ; 03FA: F8
                ret                                          ; 03FB: C3

; ---------------------------------------------------------------------------
; Print the current one/two-side status message; preserve DX.
; ---------------------------------------------------------------------------

show_sides:
                push    dx                                   ; 03FC: 52
                mov     dx,data_0594                         ; 03FD: BA 94 05
                mov     ah,9h                                ; 0400: B4 09
                int     21h                                  ; 0402: CD 21
                pop     dx                                   ; 0404: 5A
                ret                                          ; 0405: C3

; ---------------------------------------------------------------------------
; Compare buffered bytes with REPE CMPSB and report differences.
; ---------------------------------------------------------------------------

compare_buffers:
                mov     si,ds:[second_buffer_offset]         ; 0406: 8B 36 91 04
                mov     es,word ptr ds:[compare_buffer_segment]; 040A: 8E 06 8D 04
                xor     di,di                                ; 040E: 33 FF
                mov     cx,2000h                             ; 0410: B9 00 20

loc_0413:
                jcxz    loc_041E                             ; 0413: E3 09
                repe    cmpsb                                ; 0415: F3 A6
                jz      loc_041E                             ; 0417: 74 05
                call    report_mismatch                      ; 0419: E8 0C 00
                jmp     short loc_0413                       ; 041C: EB F5

loc_041E:
                mov     ax,ds:[compare_buffer_segment]       ; 041E: A1 8D 04
                add     ax,200h                              ; 0421: 05 00 02
                mov     ds:[compare_buffer_segment],ax       ; 0424: A3 8D 04
                ret                                          ; 0427: C3

; ---------------------------------------------------------------------------
; Report the track/side of a mismatch; adjust the remaining comparison span.
; ---------------------------------------------------------------------------

report_mismatch:
                or      byte ptr ds:[compare_flags],4h       ; 0428: 80 0E 97 04 04
                mov     dl,ds:[current_track]                ; 042D: 8A 16 93 04
                mov     dh,30h                               ; 0431: B6 30
                cmp     cx,0FFFh                             ; 0433: 81 F9 FF 0F
                ja      loc_044A                             ; 0437: 77 11
                xor     cx,cx                                ; 0439: 33 C9
                test    byte ptr ds:[compare_flags],40h      ; 043B: F6 06 97 04 40
                jz      loc_0446                             ; 0440: 74 04
                inc     dh                                   ; 0442: FE C6
                jmp     short loc_045D                       ; 0444: EB 17

loc_0446:
                inc     dl                                   ; 0446: FE C2
                jmp     short loc_045D                       ; 0448: EB 13

loc_044A:
                mov     bp,ds:[compare_buffer_segment]       ; 044A: 8B 2E 8D 04
                add     bp,100h                              ; 044E: 81 C5 00 01
                mov     es,bp                                ; 0452: 8E C5
                add     si,cx                                ; 0454: 03 F1
                mov     cx,1000h                             ; 0456: B9 00 10
                sub     si,cx                                ; 0459: 2B F1
                xor     di,di                                ; 045B: 33 FF

loc_045D:
                mov     ds:[data_0556],dh                    ; 045D: 88 36 56 05
                mov     word ptr ds:[data_054D],3030h        ; 0461: C7 06 4D 05 30 30

loc_0467:
                rawop   82h,0FAh,0Ah                         ; 0467: 82 FA 0A ; cmp dl,0Ah
                jc      loc_0475                             ; 046A: 72 09
                inc     byte ptr ds:[data_054D]              ; 046C: FE 06 4D 05
                rawop   82h,0EAh,0Ah                         ; 0470: 82 EA 0A ; sub dl,0Ah
                jmp     short loc_0467                       ; 0473: EB F2

loc_0475:
                mov     ds:[data_054E],dl                    ; 0475: 88 16 4E 05
                or      byte ptr ds:[data_054E],30h          ; 0479: 80 0E 4E 05 30
                mov     dx,data_055B                         ; 047E: BA 5B 05
                mov     ah,9h                                ; 0481: B4 09
                int     21h                                  ; 0483: CD 21
                mov     dx,data_0547                         ; 0485: BA 47 05
                int     21h                                  ; 0488: CD 21
                ret                                          ; 048A: C3

; read_buffer_segment (048Bh)
                db      0h,0h                                 ; 048B: 00 00

; compare_buffer_segment (048Dh)
                db      0h,0h                                 ; 048D: 00 00

; second_buffer_segment (048Fh)
                db      0h,0h                                 ; 048F: 00 00

; second_buffer_offset (0491h)
                db      0h,0h                                 ; 0491: 00 00

; current_track (0493h)
                db      0h                                    ; 0493: 00

; other_side (0494h)
                db      0h                                    ; 0494: 00

; tracks_per_buffer (0495h)
                db      0h                                    ; 0495: 00

; end_track (0496h)
                db      0h                                    ; 0496: 00

; compare_flags (0497h)
                db      0h                                    ; 0497: 00

; read_retries (0498h)
                db      0h                                    ; 0498: 00

; second_read_count (0499h)
                db      0h                                    ; 0499: 00

; buffer_end_track (049Ah)
                db      0h                                    ; 049A: 00

; data_049B (049Bh)
                db      0Dh,0Ah                               ; 049B: 0D 0A
                db      "Insert first diskette in drive "     ; 049D: 31 data bytes

; data_04BC (04BCh)
                db      "@:"                                  ; 04BC: 40 3A
                db      0Dh,0Ah                               ; 04BE: 0D 0A
                db      "$"                                   ; 04C0: 24

; data_04C1 (04C1h)
                db      0Dh,0Ah                               ; 04C1: 0D 0A
                db      "Insert second diskette in drive "    ; 04C3: 32 data bytes

; data_04E3 (04E3h)
                db      "@:"                                  ; 04E3: 40 3A
                db      0Dh,0Ah                               ; 04E5: 0D 0A
                db      "$"                                   ; 04E7: 24

; data_04E8 (04E8h)
                db      0Dh,0Ah                               ; 04E8: 0D 0A
                db      "Strike any key when ready"           ; 04EA: 25 data bytes
                db      0Dh,0Ah                               ; 0503: 0D 0A
                db      "$"                                   ; 0505: 24

; data_0506 (0506h)
                db      0Dh,0Ah                               ; 0506: 0D 0A
                db      "Diskettes compare ok"                ; 0508: 20 data bytes
                db      0Dh,0Ah                               ; 051C: 0D 0A
                db      "$"                                   ; 051E: 24

; data_051F (051Fh)
                db      0Dh,0Ah                               ; 051F: 0D 0A
                db      "Unrecoverable read error on drive "  ; 0521: 34 data bytes

; data_0543 (0543h)
                db      "@"                                   ; 0543: 40
                db      0Dh,0Ah                               ; 0544: 0D 0A
                db      "$"                                   ; 0546: 24

; data_0547 (0547h)
                db      "Track "                              ; 0547: 54 72 61 63 6B 20

; data_054D (054Dh)
                db      0h                                    ; 054D: 00

; data_054E (054Eh)
                db      0h                                    ; 054E: 00
                db      ", Side "                             ; 054F: 2C 20 53 69 64 65 20

; data_0556 (0556h)
                db      0h,0Dh,0Ah,7h                         ; 0556: 00 0D 0A 07
                db      "$"                                   ; 055A: 24

; data_055B (055Bh)
                db      0Dh,0Ah                               ; 055B: 0D 0A
                db      "Compare error(s) on "                ; 055D: 20 data bytes
                db      0Dh,0Ah                               ; 0571: 0D 0A
                db      "$"                                   ; 0573: 24

; data_0574 (0574h)
                db      0Dh,0Ah                               ; 0574: 0D 0A
                db      "Compare more diskettes (Y/N)?$"      ; 0576: 30 data bytes

; data_0594 (0594h)
                db      0Dh,0Ah                               ; 0594: 0D 0A
                db      "Comparing "                          ; 0596: 43 6F 6D 70 61 72 69 6E 67 20

; data_05A0 (05A0h)
                db      0h                                    ; 05A0: 00
                db      " side(s)"                            ; 05A1: 20 73 69 64 65 28 73 29
                db      0Dh,0Ah                               ; 05A9: 0D 0A
                db      "$"                                   ; 05AB: 24

; data_05AC (05ACh)
                db      0Dh,0Ah                               ; 05AC: 0D 0A
                db      "Incompatible diskette or drive types"; 05AE: 36 data bytes
                db      0Dh,0Ah,7h                            ; 05D2: 0D 0A 07
                db      "$"                                   ; 05D5: 24

; data_05D6 (05D6h)
                db      0Dh,0Ah                               ; 05D6: 0D 0A
                db      "Not ready error reading drive $"     ; 05D8: 31 data bytes

; data_05F7 (05F7h)
                db      0Dh,0Ah                               ; 05F7: 0D 0A
                db      "Correct, then strike any key"        ; 05F9: 28 data bytes
                db      0Dh,0Ah,7h                            ; 0615: 0D 0A 07
                db      "$"                                   ; 0618: 24

; ---------------------------------------------------------------------------
; Initialize drive selection and buffer allocation; parse the /1 option.
; ---------------------------------------------------------------------------

init:
                cld                                          ; 0619: FC
                mov     byte ptr ds:[compare_flags],0h       ; 061A: C6 06 97 04 00
                mov     byte ptr ds:[other_side],1h          ; 061F: C6 06 94 04 01
                mov     sp,100h                              ; 0624: BC 00 01
                xor     dx,dx                                ; 0627: 33 D2
                push    dx                                   ; 0629: 52
                or      ah,al                                ; 062A: 0A E0
                rawop   82h,0FCh,0FFh                        ; 062C: 82 FC FF ; cmp ah,0FFh
                jz      loc_0679                             ; 062F: 74 48
                mov     dx,data_0751                         ; 0631: BA 51 07
                rawop   82h,3Eh,5Dh,0h,20h                   ; 0634: 82 3E 5D 00 20 ; cmp byte ptr ds:[fcb1_name],20h
                jnz     loc_067C                             ; 0639: 75 41
                rawop   82h,3Eh,6Dh,0h,20h                   ; 063B: 82 3E 6D 00 20 ; cmp byte ptr ds:[fcb2_name],20h
                jnz     loc_067C                             ; 0640: 75 3A
                mov     ah,ds:[fcb2_drive]                   ; 0642: 8A 26 6C 00
                mov     ds:[fcb1_name],ah                    ; 0646: 88 26 5D 00
                int     11h                                  ; 064A: CD 11
                mov     cl,6h                                ; 064C: B1 06
                shr     al,cl                                ; 064E: D2 E8
                and     al,3h                                ; 0650: 24 03
                inc     al                                   ; 0652: FE C0
                mov     bl,al                                ; 0654: 8A D8
                mov     ah,19h                               ; 0656: B4 19
                int     21h                                  ; 0658: CD 21
                inc     al                                   ; 065A: FE C0
                rawop   82h,0FBh,1h                          ; 065C: 82 FB 01 ; cmp bl,1h
                jnz     loc_066D                             ; 065F: 75 0C
                mov     byte ptr ds:[fcb1_drive],1h          ; 0661: C6 06 5C 00 01
                mov     byte ptr ds:[fcb1_name],1h           ; 0666: C6 06 5D 00 01
                jmp     short loc_068C                       ; 066B: EB 1F

loc_066D:
                test    byte ptr ds:[fcb1_drive],0FFh        ; 066D: F6 06 5C 00 FF
                jnz     loc_0682                             ; 0672: 75 0E
                mov     ds:[fcb1_drive],al                   ; 0674: A2 5C 00
                jmp     short loc_0682                       ; 0677: EB 09

loc_0679:
                mov     dx,data_0717                         ; 0679: BA 17 07

loc_067C:
                mov     ah,9h                                ; 067C: B4 09
                int     21h                                  ; 067E: CD 21
                int     20h                                  ; 0680: CD 20

loc_0682:
                test    byte ptr ds:[fcb1_name],0FFh         ; 0682: F6 06 5D 00 FF
                jnz     loc_068C                             ; 0687: 75 03
                mov     ds:[fcb1_name],al                    ; 0689: A2 5D 00

loc_068C:
                mov     al,ds:[fcb1_drive]                   ; 068C: A0 5C 00
                or      ds:[data_04BC],al                    ; 068F: 08 06 BC 04
                dec     al                                   ; 0693: FE C8
                mov     ds:[fcb1_drive],al                   ; 0695: A2 5C 00
                mov     ah,al                                ; 0698: 8A E0
                mov     al,ds:[fcb1_name]                    ; 069A: A0 5D 00
                or      ds:[data_04E3],al                    ; 069D: 08 06 E3 04
                dec     al                                   ; 06A1: FE C8
                mov     ds:[fcb1_name],al                    ; 06A3: A2 5D 00
                cmp     al,ah                                ; 06A6: 3A C4
                jnz     loc_06AF                             ; 06A8: 75 05
                or      byte ptr ds:[compare_flags],1h       ; 06AA: 80 0E 97 04 01

loc_06AF:
                mov     dx,offset init                       ; 06AF: BA 19 06
                mov     cl,4h                                ; 06B2: B1 04
                shr     dx,cl                                ; 06B4: D3 EA
                mov     ax,cs                                ; 06B6: 8C C8
                add     dx,ax                                ; 06B8: 03 D0
                xor     dl,dl                                ; 06BA: 32 D2
                inc     dh                                   ; 06BC: FE C6
                mov     ds:[second_buffer_segment],dx        ; 06BE: 89 16 8F 04
                mov     bx,dx                                ; 06C2: 8B DA
                sub     bx,ax                                ; 06C4: 2B D8
                mov     cl,4h                                ; 06C6: B1 04
                shl     bx,cl                                ; 06C8: D3 E3
                mov     ds:[second_buffer_offset],bx         ; 06CA: 89 1E 91 04
                mov     ax,ds:[psp_end_segment]              ; 06CE: A1 02 00
                sub     ax,dx                                ; 06D1: 2B C2
                mov     cl,8h                                ; 06D3: B1 08
                shr     ax,cl                                ; 06D5: D3 E8
                and     al,0FEh                              ; 06D7: 24 FE
                add     dx,200h                              ; 06D9: 81 C2 00 02
                mov     ds:[read_buffer_segment],dx          ; 06DD: 89 16 8B 04
                mov     dx,data_0738                         ; 06E1: BA 38 07
                cmp     ax,4h                                ; 06E4: 3D 04 00
                jc      loc_067C                             ; 06E7: 72 93
                sub     ax,2h                                ; 06E9: 2D 02 00
                mov     ds:[tracks_per_buffer],al            ; 06EC: A2 95 04
                xor     ch,ch                                ; 06EF: 32 ED
                mov     cl,ds:[command_length]               ; 06F1: 8A 0E 80 00
                jcxz    loc_070F                             ; 06F5: E3 18
                mov     di,81h                               ; 06F7: BF 81 00
                mov     al,2Fh                               ; 06FA: B0 2F
                repne   scasb                                ; 06FC: F2 AE
                jnz     loc_070F                             ; 06FE: 75 0F
                rawop   82h,3Dh,31h                          ; 0700: 82 3D 31 ; cmp byte ptr [di],31h
                jnz     loc_070F                             ; 0703: 75 0A
                or      byte ptr ds:[compare_flags],2h       ; 0705: 80 0E 97 04 02
                mov     byte ptr ds:[other_side],0h          ; 070A: C6 06 94 04 00

loc_070F:
                mov     byte ptr ds:[second_read_count],2h   ; 070F: C6 06 99 04 02
                jmpn    compare_again                        ; 0714: E9 8F FA

; data_0717 (0717h)
                db      0Dh,0Ah                               ; 0717: 0D 0A
                db      "Invalid drive specification"         ; 0719: 27 data bytes
                db      7h,0Dh,0Ah                            ; 0734: 07 0D 0A
                db      "$"                                   ; 0737: 24

; data_0738 (0738h)
                db      0Dh,0Ah                               ; 0738: 0D 0A
                db      "Insufficient memory"                 ; 073A: 19 data bytes
                db      7h,0Dh,0Ah                            ; 074D: 07 0D 0A
                db      "$"                                   ; 0750: 24

; data_0751 (0751h)
                db      0Dh,0Ah                               ; 0751: 0D 0A
                db      "Invalid parameter"                   ; 0753: 17 data bytes
                db      7h,0Dh,0Ah                            ; 0764: 07 0D 0A
                db      "$"                                   ; 0767: 24

program         ends
                end     start
