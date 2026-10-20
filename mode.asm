;*-------------------------------------------------------------------------
;  MODE.ASM - PC DOS 1.10 display, printer and serial configuration
;
;  Build: make mode.com     Verify: make check-utilities
;  Original: bin/mode.com, 2509 bytes; COM load address 0100h.
;  Each emitted line records its COM address and original bytes.
;  File offset = COM address - 0100h. Numeric loc_ / data_ names retain
;  addresses where a fuller semantic name has not yet been established.
;  This is an exact static mapping; runtime behavior has not been tested.
;
;  Layout:
;    0100h-0105h  code
;    02C6h-033Eh  code
;    03B2h-0503h  code
;    0548h-0604h  code
;    0615h-065Bh  code
;    0662h-068Dh  code
;    06B4h-074Bh  code
;    0751h-0780h  code
;    0808h-08C9h  code
;    0918h-0ACCh  code
;  All remaining image bytes are initialized data, messages, or tables.
;  MODE copies interrupt handler templates to segment 0000h at 0580h.
;-------------------------------------------------------------------------

program         segment
                assume  cs:program, ds:program
                org     100h

; Preserve near jumps even when the target is in short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

; rawop preserves the literal far CALL/JMP slots patched by install_resident.
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
data_0050               equ     50h
data_0052               equ     52h
data_005C               equ     5Ch
data_005E               equ     5Eh
data_0074               equ     74h
data_0076               equ     76h
command_length          equ     80h
command_tail            equ     81h
data_0092               equ     92h
data_00A2               equ     0A2h
data_00B2               equ     0B2h
command_buffer          equ     106h
device_number           equ     109h
device_colon            equ     10Ah
device_argument         equ     10Bh
redirect_com_number     equ     10Fh
second_argument         equ     110h
third_argument          equ     111h
video_mode              equ     112h
comma_count             equ     113h
video_done              equ     340h
invalid_video_option    equ     341h
test_digits             equ     342h
data_034D               equ     34Dh
data_0374               equ     374h
data_039A               equ     39Ah
data_0471               equ     471h
printer_work            equ     504h
data_0510               equ     510h
data_0515               equ     515h
data_0529               equ     529h
data_052E               equ     52Eh
data_0533               equ     533h
data_05BB               equ     5BBh
data_05C2               equ     5C2h
data_05C4               equ     5C4h
printer_dispatch_table  equ     605h
decimal_hundreds        equ     660h
decimal_tens            equ     661h
data_0690               equ     690h
data_0717               equ     717h
data_0719               equ     719h
data_0757               equ     757h
data_0759               equ     759h
data_0790               equ     790h
data_07A9               equ     7A9h
data_07BC               equ     7BCh
data_07C1               equ     7C1h
data_07D1               equ     7D1h
data_07D6               equ     7D6h
data_07E7               equ     7E7h
printer_number          equ     806h
baud_rate_table         equ     8D0h
data_08E0               equ     8E0h
data_0901               equ     901h
data_0906               equ     906h
baud_text               equ     909h
data_090B               equ     90Bh
parity_text             equ     90Eh
data_bits_text          equ     910h
stop_bits_text          equ     912h
retry_text              equ     914h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Set the transient stack at 0100h and enter command parsing.
; ---------------------------------------------------------------------------

start:
                mov     sp,100h                              ; 0100: BC 00 01
                jmpn    parse_command                        ; 0103: E9 C0 01

; command_buffer (0106h)
                db      0h,0h,0h                              ; 0106: 00 00 00

; device_number (0109h)
                db      0h                                    ; 0109: 00

; device_colon (010Ah)
                db      0h                                    ; 010A: 00

; device_argument (010Bh)
                db      0h,0h,0h,0h                           ; 010B: 00 00 00 00

; redirect_com_number (010Fh)
                db      0h                                    ; 010F: 00

; second_argument (0110h)
                db      0h                                    ; 0110: 00

; third_argument (0111h)
                db      0h                                    ; 0111: 00

; video_mode (0112h)
                db      0h                                    ; 0112: 00

; comma_count (0113h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0113: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 011F: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 012B: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0137: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0143: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 014F: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 015B: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0167: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0173: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 017F: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 018B: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0197: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01A3: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01AF: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01BB: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01C7: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01D3: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01DF: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01EB: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 01F7: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0203: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h      ; 020F: 00 00 00 00 00 00 00 00 00 00 00
                db      "The IBM Personal Computer Mode command V"; 021A: 40 data bytes
                db      "ersion 1.10 (C)Copyright IBM Corp 1982 L"; 0242: 40 data bytes
                db      "icensed Material - Program Property of I"; 026A: 40 data bytes
                db      "BM Authors - Mel Hallerman, Ron Heiney, "; 0292: 40 data bytes
                db      "and Ed Kiser"                        ; 02BA: 61 6E 64 20 45 64 20 4B 69 73 65 72

; ---------------------------------------------------------------------------
; Split the PSP command tail into the device and comma-separated arguments.
; ---------------------------------------------------------------------------

parse_command:
                mov     cx,0h                                ; 02C6: B9 00 00
                push    cx                                   ; 02C9: 51
                mov     cl,ds:[command_length]               ; 02CA: 8A 0E 80 00
                jcxz    loc_0337                             ; 02CE: E3 67
                mov     bp,81h                               ; 02D0: BD 81 00
                mov     bx,command_buffer                    ; 02D3: BB 06 01

loc_02D6:
                mov     al,es:[bp+0h]                        ; 02D6: 26 8A 46 00
                cmp     al,20h                               ; 02DA: 3C 20
                jz      loc_030C                             ; 02DC: 74 2E
                cmp     al,2Ch                               ; 02DE: 3C 2C
                jnz     loc_0309                             ; 02E0: 75 27
                cmp     byte ptr ds:[comma_count],2h         ; 02E2: 80 3E 13 01 02
                jz      loc_0304                             ; 02E7: 74 1B
                cmp     byte ptr ds:[comma_count],1h         ; 02E9: 80 3E 13 01 01
                jz      loc_02FA                             ; 02EE: 74 0A
                mov     byte ptr ds:[comma_count],1h         ; 02F0: C6 06 13 01 01
                mov     bx,second_argument                   ; 02F5: BB 10 01
                jmp     short loc_0302                       ; 02F8: EB 08

loc_02FA:
                mov     byte ptr ds:[comma_count],2h         ; 02FA: C6 06 13 01 02
                mov     bx,third_argument                    ; 02FF: BB 11 01

loc_0302:
                jmp     short loc_0307                       ; 0302: EB 03

loc_0304:
                mov     bx,video_mode                        ; 0304: BB 12 01

loc_0307:
                jmp     short loc_030C                       ; 0307: EB 03

loc_0309:
                mov     [bx],al                              ; 0309: 88 07
                inc     bx                                   ; 030B: 43

loc_030C:
                cmp     bx,112h                              ; 030C: 81 FB 12 01
                jz      loc_0315                             ; 0310: 74 03
                inc     bp                                   ; 0312: 45
                loop    loc_02D6                             ; 0313: E2 C1

loc_0315:
                or      byte ptr ds:[command_buffer],20h     ; 0315: 80 0E 06 01 20
                cmp     byte ptr ds:[command_buffer],6Ch     ; 031A: 80 3E 06 01 6C
                jnz     loc_0326                             ; 031F: 75 05
                call    set_printer_mode                     ; 0321: E8 FA 04
                jmp     short loc_0335                       ; 0324: EB 0F

loc_0326:
                cmp     byte ptr ds:[command_buffer],63h     ; 0326: 80 3E 06 01 63
                jnz     loc_0332                             ; 032B: 75 05
                call    set_serial_mode                      ; 032D: E8 F7 06
                jmp     short loc_0335                       ; 0330: EB 03

loc_0332:
                call    set_video_mode                       ; 0332: E8 AE 00

loc_0335:
                jmp     short loc_033E                       ; 0335: EB 07

loc_0337:
                mov     dx,data_039A                         ; 0337: BA 9A 03
                mov     ah,9h                                ; 033A: B4 09
                int     21h                                  ; 033C: CD 21

loc_033E:
                ret                                          ; 033E: C3
                db      0h                                    ; 033F: 00

; video_done (0340h)
                db      0h                                    ; 0340: 00

; invalid_video_option (0341h)
                db      1h                                    ; 0341: 01

; test_digits (0342h)
                db      "0123456789$"                         ; 0342: 30 31 32 33 34 35 36 37 38 39 24

; data_034D (034Dh)
                db      0Dh,0Ah                               ; 034D: 0D 0A
                db      "Do you see the rightmost 9? (Y/N) "  ; 034F: 34 data bytes
                db      0Dh,0Ah                               ; 0371: 0D 0A
                db      "$"                                   ; 0373: 24

; data_0374 (0374h)
                db      0Dh,0Ah                               ; 0374: 0D 0A
                db      "Do you see the leftmost 0? (Y/N) "   ; 0376: 33 data bytes
                db      0Dh,0Ah                               ; 0397: 0D 0A
                db      "$"                                   ; 0399: 24

; data_039A (039Ah)
                db      0Dh,0Ah                               ; 039A: 0D 0A
                db      "Invalid parameters"                  ; 039C: 18 data bytes
                db      7h,0Dh,0Ah                            ; 03AE: 07 0D 0A
                db      "$"                                   ; 03B1: 24

; ---------------------------------------------------------------------------
; Copy the BIOS video parameter table to 0040:0090 if needed; return DS=0040h.
; ---------------------------------------------------------------------------

copy_video_table:
                push    es                                   ; 03B2: 06
                mov     ax,0h                                ; 03B3: B8 00 00
                mov     ds,ax                                ; 03B6: 8E D8
                mov     bx,ds:[data_0076]                    ; 03B8: 8B 1E 76 00
                cmp     bx,40h                               ; 03BC: 83 FB 40
                jz      loc_03DC                             ; 03BF: 74 1B
                mov     di,90h                               ; 03C1: BF 90 00
                mov     ax,40h                               ; 03C4: B8 40 00
                mov     es,ax                                ; 03C7: 8E C0
                mov     si,ds:[data_0074]                    ; 03C9: 8B 36 74 00
                mov     ds:[data_0074],di                    ; 03CD: 89 3E 74 00
                mov     word ptr ds:[data_0076],es           ; 03D1: 8C 06 76 00
                mov     ds,bx                                ; 03D5: 8E DB
                mov     cx,20h                               ; 03D7: B9 20 00
                rep     movsw                                ; 03DA: F3 A5

loc_03DC:
                mov     ax,40h                               ; 03DC: B8 40 00
                mov     ds,ax                                ; 03DF: 8E D8
                pop     es                                   ; 03E1: 07
                ret                                          ; 03E2: C3

; ---------------------------------------------------------------------------
; Configure 40/80 columns and horizontal alignment; optionally show a test pattern.
; ---------------------------------------------------------------------------

set_video_mode:
                mov     bp,106h                              ; 03E3: BD 06 01
                call    parse_decimal                        ; 03E6: E8 79 02
                mov     ah,0Fh                               ; 03E9: B4 0F
                mov     al,0h                                ; 03EB: B0 00
                int     10h                                  ; 03ED: CD 10
                mov     ds:[video_mode],al                   ; 03EF: A2 12 01
                cmp     bl,28h                               ; 03F2: 80 FB 28
                jnz     loc_040A                             ; 03F5: 75 13
                mov     byte ptr ds:[invalid_video_option],0h; 03F7: C6 06 41 03 00
                and     byte ptr ds:[video_mode],1h          ; 03FC: 80 26 12 01 01
                mov     ah,0h                                ; 0401: B4 00
                mov     al,ds:[video_mode]                   ; 0403: A0 12 01
                int     10h                                  ; 0406: CD 10
                jmp     short loc_0420                       ; 0408: EB 16

loc_040A:
                cmp     bl,50h                               ; 040A: 80 FB 50
                jnz     loc_0420                             ; 040D: 75 11
                mov     byte ptr ds:[invalid_video_option],0h; 040F: C6 06 41 03 00
                or      byte ptr ds:[video_mode],2h          ; 0414: 80 0E 12 01 02
                mov     ah,0h                                ; 0419: B4 00
                mov     al,ds:[video_mode]                   ; 041B: A0 12 01
                int     10h                                  ; 041E: CD 10

loc_0420:
                mov     byte ptr ds:[video_done],0h          ; 0420: C6 06 40 03 00

loc_0425:
                or      byte ptr ds:[second_argument],20h    ; 0425: 80 0E 10 01 20
                cmp     byte ptr ds:[second_argument],72h    ; 042A: 80 3E 10 01 72
                jnz     loc_0453                             ; 042F: 75 22
                mov     byte ptr ds:[invalid_video_option],0h; 0431: C6 06 41 03 00
                call    copy_video_table                     ; 0436: E8 79 FF
                mov     al,ds:[data_0092]                    ; 0439: A0 92 00
                sub     al,1h                                ; 043C: 2C 01
                mov     ds:[data_0092],al                    ; 043E: A2 92 00
                mov     al,ds:[data_00A2]                    ; 0441: A0 A2 00
                sub     al,2h                                ; 0444: 2C 02
                mov     ds:[data_00A2],al                    ; 0446: A2 A2 00
                mov     al,ds:[data_00B2]                    ; 0449: A0 B2 00
                sub     al,1h                                ; 044C: 2C 01
                mov     ds:[data_00B2],al                    ; 044E: A2 B2 00
                jmp     short loc_0482                       ; 0451: EB 2F

loc_0453:
                cmp     byte ptr ds:[second_argument],6Ch    ; 0453: 80 3E 10 01 6C
                jnz     loc_047C                             ; 0458: 75 22
                mov     byte ptr ds:[invalid_video_option],0h; 045A: C6 06 41 03 00
                call    copy_video_table                     ; 045F: E8 50 FF
                mov     al,ds:[data_0092]                    ; 0462: A0 92 00
                add     al,1h                                ; 0465: 04 01
                mov     ds:[data_0092],al                    ; 0467: A2 92 00
                mov     al,ds:[data_00A2]                    ; 046A: A0 A2 00
                add     al,2h                                ; 046D: 04 02
                mov     ds:[data_00A2],al                    ; 046F: A2 A2 00
                mov     al,ds:[data_00B2]                    ; 0472: A0 B2 00
                add     al,1h                                ; 0475: 04 01
                mov     ds:[data_00B2],al                    ; 0477: A2 B2 00
                jmp     short loc_0482                       ; 047A: EB 06

loc_047C:
                mov     byte ptr cs:[video_done],1h          ; 047C: 2E C6 06 40 03 01

loc_0482:
                mov     ax,cs                                ; 0482: 8C C8
                mov     ds,ax                                ; 0484: 8E D8
                cmp     byte ptr ds:[video_done],1h          ; 0486: 80 3E 40 03 01
                jz      loc_04F5                             ; 048B: 74 68
                mov     ah,0Fh                               ; 048D: B4 0F
                mov     al,0h                                ; 048F: B0 00
                int     10h                                  ; 0491: CD 10
                mov     ds:[video_mode],al                   ; 0493: A2 12 01
                mov     ah,0h                                ; 0496: B4 00
                int     10h                                  ; 0498: CD 10
                or      byte ptr ds:[third_argument],20h     ; 049A: 80 0E 11 01 20
                cmp     byte ptr ds:[third_argument],74h     ; 049F: 80 3E 11 01 74
                jnz     loc_04E6                             ; 04A4: 75 40
                or      byte ptr ds:[video_mode],1h          ; 04A6: 80 0E 12 01 01
                mov     cx,8h                                ; 04AB: B9 08 00
                cmp     byte ptr ds:[video_mode],1h          ; 04AE: 80 3E 12 01 01
                jnz     loc_04B8                             ; 04B3: 75 03
                mov     cx,4h                                ; 04B5: B9 04 00

loc_04B8:
                mov     dx,test_digits                       ; 04B8: BA 42 03
                mov     ah,9h                                ; 04BB: B4 09
                int     21h                                  ; 04BD: CD 21
                loop    loc_04B8                             ; 04BF: E2 F7
                cmp     byte ptr ds:[second_argument],72h    ; 04C1: 80 3E 10 01 72
                jnz     loc_04CD                             ; 04C6: 75 05
                mov     dx,data_0374                         ; 04C8: BA 74 03
                jmp     short loc_04D0                       ; 04CB: EB 03

loc_04CD:
                mov     dx,data_034D                         ; 04CD: BA 4D 03

loc_04D0:
                mov     ah,9h                                ; 04D0: B4 09
                int     21h                                  ; 04D2: CD 21
                mov     ax,0C01h                             ; 04D4: B8 01 0C
                int     21h                                  ; 04D7: CD 21
                or      al,20h                               ; 04D9: 0C 20
                cmp     al,79h                               ; 04DB: 3C 79
                jnz     loc_04E4                             ; 04DD: 75 05
                mov     byte ptr ds:[video_done],1h          ; 04DF: C6 06 40 03 01

loc_04E4:
                jmp     short loc_04EB                       ; 04E4: EB 05

loc_04E6:
                mov     byte ptr ds:[video_done],1h          ; 04E6: C6 06 40 03 01

loc_04EB:
                cmp     byte ptr ds:[video_done],1h          ; 04EB: 80 3E 40 03 01
                jz      loc_04F5                             ; 04F0: 74 03
                jmpn    loc_0425                             ; 04F2: E9 30 FF

loc_04F5:
                cmp     byte ptr ds:[invalid_video_option],0h; 04F5: 80 3E 41 03 00
                jz      loc_0503                             ; 04FA: 74 07
                mov     dx,data_039A                         ; 04FC: BA 9A 03
                mov     ah,9h                                ; 04FF: B4 09
                int     21h                                  ; 0501: CD 21

loc_0503:
                ret                                          ; 0503: C3

; printer_work (0504h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0504: 00 00 00 00 00 00 00 00 00 00 00 00

; data_0510 (0510h)
                db      0Dh,0Ah                               ; 0510: 0D 0A
                db      "LPT"                                 ; 0512: 4C 50 54

; data_0515 (0515h)
                db      " : redirected to COM"                ; 0515: 20 data bytes

; data_0529 (0529h)
                db      " :"                                  ; 0529: 20 3A
                db      0Dh,0Ah                               ; 052B: 0D 0A
                db      "$"                                   ; 052D: 24

; data_052E (052Eh)
                db      0Dh,0Ah                               ; 052E: 0D 0A
                db      "LPT"                                 ; 0530: 4C 50 54

; data_0533 (0533h)
                db      " : not redirected."                  ; 0533: 18 data bytes
                db      0Dh,0Ah                               ; 0545: 0D 0A
                db      "$"                                   ; 0547: 24

; ---------------------------------------------------------------------------
; Select LPT1..3. Return AH=printer mask, SI=printer number; AH=0 on invalid name.
; ---------------------------------------------------------------------------

select_printer:
                call    install_resident                     ; 0548: E8 69 01
                sub     ax,ax                                ; 054B: 2B C0
                mov     es,ax                                ; 054D: 8E C0
                mov     al,ds:[device_number]                ; 054F: A0 09 01
                mov     ds:[data_0515],al                    ; 0552: A2 15 05
                mov     ds:[data_0533],al                    ; 0555: A2 33 05
                cmp     al,31h                               ; 0558: 3C 31
                jnz     loc_0563                             ; 055A: 75 07
                mov     ah,1h                                ; 055C: B4 01
                mov     si,1h                                ; 055E: BE 01 00
                jmp     short loc_0582                       ; 0561: EB 1F

loc_0563:
                cmp     al,32h                               ; 0563: 3C 32
                jnz     loc_056E                             ; 0565: 75 07
                mov     ah,2h                                ; 0567: B4 02
                mov     si,2h                                ; 0569: BE 02 00
                jmp     short loc_0582                       ; 056C: EB 14

loc_056E:
                cmp     al,33h                               ; 056E: 3C 33
                jnz     loc_0579                             ; 0570: 75 07
                mov     ah,4h                                ; 0572: B4 04
                mov     si,3h                                ; 0574: BE 03 00
                jmp     short loc_0582                       ; 0577: EB 09

loc_0579:
                mov     dx,data_0790                         ; 0579: BA 90 07
                mov     ah,9h                                ; 057C: B4 09
                int     21h                                  ; 057E: CD 21
                mov     ah,0h                                ; 0580: B4 00

loc_0582:
                ret                                          ; 0582: C3

; ---------------------------------------------------------------------------
; Redirect an LPT device to COM1 or COM2 using the resident INT 17h handler.
; ---------------------------------------------------------------------------

redirect_printer:
                push    es                                   ; 0583: 06
                call    select_printer                       ; 0584: E8 C1 FF
                cmp     ah,0h                                ; 0587: 80 FC 00
                jz      loc_05CD                             ; 058A: 74 41
                mov     dl,0h                                ; 058C: B2 00
                mov     al,ds:[redirect_com_number]          ; 058E: A0 0F 01
                mov     ds:[data_0529],al                    ; 0591: A2 29 05
                cmp     al,31h                               ; 0594: 3C 31
                jnz     loc_059C                             ; 0596: 75 04
                mov     dl,1h                                ; 0598: B2 01
                jmp     short loc_05AD                       ; 059A: EB 11

loc_059C:
                cmp     al,32h                               ; 059C: 3C 32
                jnz     loc_05A4                             ; 059E: 75 04
                mov     dl,2h                                ; 05A0: B2 02
                jmp     short loc_05AD                       ; 05A2: EB 09

loc_05A4:
                push    dx                                   ; 05A4: 52
                mov     dx,data_0790                         ; 05A5: BA 90 07
                mov     ah,9h                                ; 05A8: B4 09
                int     21h                                  ; 05AA: CD 21
                pop     dx                                   ; 05AC: 5A

loc_05AD:
                cmp     dl,0h                                ; 05AD: 80 FA 00
                jz      loc_05CD                             ; 05B0: 74 1B
                or      ah,es:[5F0h]                         ; 05B2: 26 0A 26 F0 05
                mov     es:[5F0h],ah                         ; 05B7: 26 88 26 F0 05
                dec     dl                                   ; 05BC: FE CA
                mov     es:[si+5F0h],dl                      ; 05BE: 26 88 94 F0 05
                call    patch_printer_dispatch               ; 05C3: E8 2B 00
                mov     dx,data_0510                         ; 05C6: BA 10 05
                mov     ah,9h                                ; 05C9: B4 09
                int     21h                                  ; 05CB: CD 21

loc_05CD:
                pop     es                                   ; 05CD: 07
                ret                                          ; 05CE: C3

; ---------------------------------------------------------------------------
; Clear an LPT redirection bit and repatch the resident printer dispatch.
; ---------------------------------------------------------------------------

unredirect_printer:
                push    es                                   ; 05CF: 06
                call    select_printer                       ; 05D0: E8 75 FF
                cmp     ah,0h                                ; 05D3: 80 FC 00
                jz      loc_05EF                             ; 05D6: 74 17
                xor     ah,0FFh                              ; 05D8: 80 F4 FF
                and     ah,es:[5F0h]                         ; 05DB: 26 22 26 F0 05
                mov     es:[5F0h],ah                         ; 05E0: 26 88 26 F0 05
                call    patch_printer_dispatch               ; 05E5: E8 09 00
                mov     dx,data_052E                         ; 05E8: BA 2E 05
                mov     ah,9h                                ; 05EB: B4 09
                int     21h                                  ; 05ED: CD 21

loc_05EF:
                pop     es                                   ; 05EF: 07
                ret                                          ; 05F0: C3

; ---------------------------------------------------------------------------
; Use the redirection mask to select a patch from printer_dispatch_table.
; ---------------------------------------------------------------------------

patch_printer_dispatch:
                mov     al,es:[5F0h]                         ; 05F1: 26 A0 F0 05
                mov     byte ptr es:[data_05C4],5h           ; 05F5: 26 C6 06 C4 05 05
                mov     ah,0h                                ; 05FB: B4 00
                shl     al,1                                 ; 05FD: D0 E0
                mov     si,ax                                ; 05FF: 8B F0
                jmp     word ptr [si+605h]                   ; 0601: FF A4 05 06

; printer_dispatch_table (0605h): selected by the three LPT redirection bits.
                dw      offset dispatch_mask_0              ; 0605: 15 06
                dw      offset dispatch_mask_1              ; 0607: 1E 06
                dw      offset dispatch_mask_2              ; 0609: 27 06
                dw      offset dispatch_mask_3              ; 060B: 30 06
                dw      offset dispatch_mask_4              ; 060D: 39 06
                dw      offset dispatch_mask_5              ; 060F: 42 06
                dw      offset dispatch_mask_6              ; 0611: 4B 06
                dw      offset dispatch_mask_7              ; 0613: 54 06

dispatch_mask_0:
                mov     word ptr es:[5C3h],0EBh              ; 0615: 26 C7 06 C3 05 EB 00
                jmp     short loc_065B                       ; 061C: EB 3D

dispatch_mask_1:
                mov     word ptr es:[data_05C2],7403h        ; 061E: 26 C7 06 C2 05 03 74
                jmp     short loc_065B                       ; 0625: EB 34

dispatch_mask_2:
                mov     word ptr es:[data_05C2],7501h        ; 0627: 26 C7 06 C2 05 01 75
                jmp     short loc_065B                       ; 062E: EB 2B

dispatch_mask_3:
                mov     word ptr es:[data_05C2],7402h        ; 0630: 26 C7 06 C2 05 02 74
                jmp     short loc_065B                       ; 0637: EB 22

dispatch_mask_4:
                mov     word ptr es:[data_05C2],7502h        ; 0639: 26 C7 06 C2 05 02 75
                jmp     short loc_065B                       ; 0640: EB 19

dispatch_mask_5:
                mov     word ptr es:[data_05C2],7401h        ; 0642: 26 C7 06 C2 05 01 74
                jmp     short loc_065B                       ; 0649: EB 10

dispatch_mask_6:
                mov     word ptr es:[data_05C2],7503h        ; 064B: 26 C7 06 C2 05 03 75
                jmp     short loc_065B                       ; 0652: EB 07

dispatch_mask_7:
                mov     word ptr es:[data_05C2],0EB00h       ; 0654: 26 C7 06 C2 05 00 EB

loc_065B:
                ret                                          ; 065B: C3
                db      0h,0h,0h,0h                           ; 065C: 00 00 00 00

; decimal_hundreds (0660h)
                db      "d"                                   ; 0660: 64

; decimal_tens (0661h)
                db      0Ah                                   ; 0661: 0A

; ---------------------------------------------------------------------------
; DS:BP points to up to three decimal digits. Return the value in BL.
; ---------------------------------------------------------------------------

parse_decimal:
                mov     bl,0h                                ; 0662: B3 00
                cmp     byte ptr ds:[bp+2h],0h               ; 0664: 3E 80 7E 02 00
                jz      loc_0678                             ; 0669: 74 0D
                mov     al,ds:[bp+0h]                        ; 066B: 3E 8A 46 00
                sub     al,30h                               ; 066F: 2C 30
                mul     byte ptr ds:[decimal_hundreds]       ; 0671: F6 26 60 06
                add     bl,al                                ; 0675: 02 D8
                inc     bp                                   ; 0677: 45

loc_0678:
                mov     al,ds:[bp+0h]                        ; 0678: 3E 8A 46 00
                sub     al,30h                               ; 067C: 2C 30
                mul     byte ptr ds:[decimal_tens]           ; 067E: F6 26 61 06
                add     bl,al                                ; 0682: 02 D8
                inc     bp                                   ; 0684: 45
                mov     al,ds:[bp+0h]                        ; 0685: 3E 8A 46 00
                sub     al,30h                               ; 0689: 2C 30
                add     bl,al                                ; 068B: 02 D8
                ret                                          ; 068D: C3
                db      0h,0h                                 ; 068E: 00 00

; data_0690 (0690h)
                db      0Dh,0Ah                               ; 0690: 0D 0A
                db      "Resident portion of MODE loaded"     ; 0692: 31 data bytes
                db      0Dh,0Ah                               ; 06B1: 0D 0A
                db      "$"                                   ; 06B3: 24

; ---------------------------------------------------------------------------
; Copy 74h bytes of handler templates to 0000:0580; hook INT 14h and INT 17h.
; ---------------------------------------------------------------------------

install_resident:
                push    es                                   ; 06B4: 06
                mov     ax,0h                                ; 06B5: B8 00 00
                mov     es,ax                                ; 06B8: 8E C0
                mov     di,580h                              ; 06BA: BF 80 05
                mov     ax,ds:[711h]                         ; 06BD: A1 11 07
                cmp     ax,es:[di]                           ; 06C0: 26 3B 05
                jz      loc_070F                             ; 06C3: 74 4A
                mov     ax,es:[data_0050]                    ; 06C5: 26 A1 50 00
                mov     ds:[data_0717],ax                    ; 06C9: A3 17 07
                mov     ax,es:[data_0052]                    ; 06CC: 26 A1 52 00
                mov     ds:[data_0719],ax                    ; 06D0: A3 19 07
                mov     ax,es:[data_005C]                    ; 06D3: 26 A1 5C 00
                mov     ds:[data_0757],ax                    ; 06D7: A3 57 07
                mov     ax,es:[data_005E]                    ; 06DA: 26 A1 5E 00
                mov     ds:[data_0759],ax                    ; 06DE: A3 59 07
                mov     si,711h                              ; 06E1: BE 11 07
                mov     cx,74h                               ; 06E4: B9 74 00
                nop                                          ; 06E7: 90
                rep     movsb                                ; 06E8: F3 A4
                cli                                          ; 06EA: FA
                mov     ax,580h                              ; 06EB: B8 80 05
                mov     es:[data_0050],ax                    ; 06EE: 26 A3 50 00
                mov     ax,0h                                ; 06F2: B8 00 00
                mov     es:[data_0052],ax                    ; 06F5: 26 A3 52 00
                mov     ax,5C0h                              ; 06F9: B8 C0 05
                mov     es:[data_005C],ax                    ; 06FC: 26 A3 5C 00
                mov     ax,0h                                ; 0700: B8 00 00
                mov     es:[data_005E],ax                    ; 0703: 26 A3 5E 00
                sti                                          ; 0707: FB
                mov     dx,data_0690                         ; 0708: BA 90 06
                mov     ah,9h                                ; 070B: B4 09
                int     21h                                  ; 070D: CD 21

loc_070F:
                pop     es                                   ; 070F: 07
                ret                                          ; 0710: C3

; ---------------------------------------------------------------------------
; INT 14h template copied to 0000:0580. Far operands are patched before copying.
; ---------------------------------------------------------------------------

serial_handler_template:
                test    dl,1h                                ; 0711: F6 C2 01
                jmp     short loc_0716                       ; 0714: EB 00

loc_0716:
                rawop   0EAh,39h,0E7h,0h,0F0h                ; 0716: EA 39 E7 00 F0 ; jmp word ptr 0F000h:word ptr 0E739h

loc_071B:
                push    ax                                   ; 071B: 50
                push    ds                                   ; 071C: 1E
                push    ax                                   ; 071D: 50
                sub     ax,ax                                ; 071E: 2B C0
                mov     ds,ax                                ; 0720: 8E D8
                and     byte ptr ds:[data_0471],7Fh          ; 0722: 80 26 71 04 7F
                pop     ax                                   ; 0727: 58
                pop     ds                                   ; 0728: 1F
                pushf                                        ; 0729: 9C
                rawop   9Ah,39h,0E7h,0h,0F0h                 ; 072A: 9A 39 E7 00 F0 ; call word ptr 0F000h:word ptr 0E739h
                push    ax                                   ; 072F: 50
                push    ds                                   ; 0730: 1E
                sub     ax,ax                                ; 0731: 2B C0
                mov     ds,ax                                ; 0733: 8E D8
                test    byte ptr ds:[data_0471],80h          ; 0735: F6 06 71 04 80
                pop     ds                                   ; 073A: 1F
                pop     ax                                   ; 073B: 58
                jz      loc_0744                             ; 073C: 74 06
                or      ah,80h                               ; 073E: 80 CC 80

loc_0741:
                inc     sp                                   ; 0741: 44
                inc     sp                                   ; 0742: 44
                iret                                         ; 0743: CF

loc_0744:
                test    ah,80h                               ; 0744: F6 C4 80
                jz      loc_0741                             ; 0747: 74 F8
                pop     ax                                   ; 0749: 58
                jmp     short loc_071B                       ; 074A: EB CF
                db      0h,0h,0h,0h,0h                        ; 074C: 00 00 00 00 00

; ---------------------------------------------------------------------------
; INT 17h template copied to 0000:05C0. Redirect output through BIOS INT 14h.
; ---------------------------------------------------------------------------

printer_handler_template:
                test    dl,1h                                ; 0751: F6 C2 01
                jmp     short loc_0756                       ; 0754: EB 00

loc_0756:
                rawop   0EAh,0D2h,0EFh,0h,0F0h               ; 0756: EA D2 EF 00 F0 ; jmp word ptr 0F000h:word ptr 0EFD2h
                cmp     ah,0h                                ; 075B: 80 FC 00
                jz      loc_0763                             ; 075E: 74 03
                mov     ah,80h                               ; 0760: B4 80
                iret                                         ; 0762: CF

loc_0763:
                push    bx                                   ; 0763: 53
                push    ax                                   ; 0764: 50
                push    dx                                   ; 0765: 52
                mov     ah,1h                                ; 0766: B4 01
                mov     bx,5F1h                              ; 0768: BB F1 05
                add     bx,dx                                ; 076B: 03 DA
                mov     dl,cs:[bx]                           ; 076D: 2E 8A 17
                int     14h                                  ; 0770: CD 14
                pop     dx                                   ; 0772: 5A
                test    ah,80h                               ; 0773: F6 C4 80
                mov     ah,10h                               ; 0776: B4 10
                jz      loc_077C                             ; 0778: 74 02
                mov     ah,9h                                ; 077A: B4 09

loc_077C:
                pop     bx                                   ; 077C: 5B
                mov     al,bl                                ; 077D: 8A C3
                pop     bx                                   ; 077F: 5B
                iret                                         ; 0780: CF
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0781: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h                              ; 078D: 00 00 00

; data_0790 (0790h)
                db      0Dh,0Ah                               ; 0790: 0D 0A
                db      "Illegal device name"                 ; 0792: 19 data bytes
                db      7h,0Dh,0Ah                            ; 07A5: 07 0D 0A
                db      "$"                                   ; 07A8: 24

; data_07A9 (07A9h)
                db      0Dh,0Ah                               ; 07A9: 0D 0A
                db      "Printer error"                       ; 07AB: 13 data bytes
                db      7h,0Dh,0Ah                            ; 07B8: 07 0D 0A
                db      "$"                                   ; 07BB: 24

; data_07BC (07BCh)
                db      0Dh,0Ah                               ; 07BC: 0D 0A
                db      "LPT"                                 ; 07BE: 4C 50 54

; data_07C1 (07C1h)
                db      " : set for 80"                       ; 07C1: 13 data bytes
                db      0Dh,0Ah                               ; 07CE: 0D 0A
                db      "$"                                   ; 07D0: 24

; data_07D1 (07D1h)
                db      0Dh,0Ah                               ; 07D1: 0D 0A
                db      "LPT"                                 ; 07D3: 4C 50 54

; data_07D6 (07D6h)
                db      " : set for 132"                      ; 07D6: 14 data bytes
                db      0Dh,0Ah                               ; 07E4: 0D 0A
                db      "$"                                   ; 07E6: 24

; data_07E7 (07E7h)
                db      0Dh,0Ah                               ; 07E7: 0D 0A
                db      "Printer lines per inch set"          ; 07E9: 26 data bytes
                db      0Dh,0Ah                               ; 0803: 0D 0A
                db      "$"                                   ; 0805: 24

; printer_number (0806h)
                db      0h,0h                                 ; 0806: 00 00

; ---------------------------------------------------------------------------
; AX=printer byte/function. Use BIOS INT 17h and report printer errors.
; ---------------------------------------------------------------------------

send_printer_byte:
                mov     dx,ds:[printer_number]               ; 0808: 8B 16 06 08
                int     17h                                  ; 080C: CD 17
                and     ah,0A9h                              ; 080E: 80 E4 A9
                cmp     ah,0h                                ; 0811: 80 FC 00
                jz      loc_081D                             ; 0814: 74 07
                mov     dx,data_07A9                         ; 0816: BA A9 07
                mov     ah,9h                                ; 0819: B4 09
                int     21h                                  ; 081B: CD 21

loc_081D:
                ret                                          ; 081D: C3

; ---------------------------------------------------------------------------
; Parse LPT configuration: redirection, width (80/132), and line spacing (6/8).
; ---------------------------------------------------------------------------

set_printer_mode:
                cmp     byte ptr ds:[device_colon],3Ah       ; 081E: 80 3E 0A 01 3A
                jz      loc_0828                             ; 0823: 74 03
                jmpn    loc_08C2                             ; 0825: E9 9A 00

loc_0828:
                cmp     byte ptr ds:[device_argument],3Dh    ; 0828: 80 3E 0B 01 3D
                jnz     loc_0835                             ; 082D: 75 06
                call    redirect_printer                     ; 082F: E8 51 FD
                jmpn    loc_08C0                             ; 0832: E9 8B 00

loc_0835:
                call    unredirect_printer                   ; 0835: E8 97 FD
                cmp     ah,0h                                ; 0838: 80 FC 00
                jnz     loc_0840                             ; 083B: 75 03
                jmpn    loc_08C0                             ; 083D: E9 80 00

loc_0840:
                mov     bp,10Bh                              ; 0840: BD 0B 01
                mov     al,ds:[device_number]                ; 0843: A0 09 01
                mov     ds:[data_07C1],al                    ; 0846: A2 C1 07
                mov     ds:[data_07D6],al                    ; 0849: A2 D6 07
                sub     al,31h                               ; 084C: 2C 31
                mov     ah,0h                                ; 084E: B4 00
                mov     ds:[printer_number],ax               ; 0850: A3 06 08
                call    parse_decimal                        ; 0853: E8 0C FE
                cmp     bl,50h                               ; 0856: 80 FB 50
                jnz     loc_0866                             ; 0859: 75 0B
                mov     dx,data_07BC                         ; 085B: BA BC 07
                mov     ah,9h                                ; 085E: B4 09
                int     21h                                  ; 0860: CD 21
                mov     bl,12h                               ; 0862: B3 12
                jmp     short loc_0878                       ; 0864: EB 12

loc_0866:
                cmp     bl,84h                               ; 0866: 80 FB 84
                jnz     loc_0876                             ; 0869: 75 0B
                mov     dx,data_07D1                         ; 086B: BA D1 07
                mov     ah,9h                                ; 086E: B4 09
                int     21h                                  ; 0870: CD 21
                mov     bl,0Fh                               ; 0872: B3 0F
                jmp     short loc_0878                       ; 0874: EB 02

loc_0876:
                mov     bl,0h                                ; 0876: B3 00

loc_0878:
                cmp     bl,0h                                ; 0878: 80 FB 00
                jz      loc_088A                             ; 087B: 74 0D
                mov     ax,18h                               ; 087D: B8 18 00
                call    send_printer_byte                    ; 0880: E8 85 FF
                mov     ah,0h                                ; 0883: B4 00
                mov     al,bl                                ; 0885: 8A C3
                call    send_printer_byte                    ; 0887: E8 7E FF

loc_088A:
                mov     bl,0h                                ; 088A: B3 00
                cmp     byte ptr ds:[second_argument],0h     ; 088C: 80 3E 10 01 00
                jz      loc_08A7                             ; 0891: 74 14
                cmp     byte ptr ds:[second_argument],36h    ; 0893: 80 3E 10 01 36
                jnz     loc_089E                             ; 0898: 75 04
                mov     bl,32h                               ; 089A: B3 32
                jmp     short loc_08A7                       ; 089C: EB 09

loc_089E:
                cmp     byte ptr ds:[second_argument],38h    ; 089E: 80 3E 10 01 38
                jnz     loc_08A7                             ; 08A3: 75 02
                mov     bl,30h                               ; 08A5: B3 30

loc_08A7:
                cmp     bl,0h                                ; 08A7: 80 FB 00
                jz      loc_08C0                             ; 08AA: 74 14
                mov     ax,1Bh                               ; 08AC: B8 1B 00
                call    send_printer_byte                    ; 08AF: E8 56 FF
                mov     ah,0h                                ; 08B2: B4 00
                mov     al,bl                                ; 08B4: 8A C3
                call    send_printer_byte                    ; 08B6: E8 4F FF
                mov     dx,data_07E7                         ; 08B9: BA E7 07
                mov     ah,9h                                ; 08BC: B4 09
                int     21h                                  ; 08BE: CD 21

loc_08C0:
                jmp     short loc_08C9                       ; 08C0: EB 07

loc_08C2:
                mov     dx,data_0790                         ; 08C2: BA 90 07
                mov     ah,9h                                ; 08C5: B4 09
                int     21h                                  ; 08C7: CD 21

loc_08C9:
                ret                                          ; 08C9: C3
                db      0h,0h,0h,0h,0h,0h                     ; 08CA: 00 00 00 00 00 00

; baud_rate_table (08D0h)
                db      "1115306012244896"                    ; 08D0: 16 data bytes

; data_08E0 (08E0h)
                db      0Dh,0Ah                               ; 08E0: 0D 0A
                db      "Invalid baud rate specified"         ; 08E2: 27 data bytes
                db      7h,0Dh,0Ah                            ; 08FD: 07 0D 0A
                db      "$"                                   ; 0900: 24

; data_0901 (0901h)
                db      0Dh,0Ah                               ; 0901: 0D 0A
                db      "COM"                                 ; 0903: 43 4F 4D

; data_0906 (0906h)
                db      " : "                                 ; 0906: 20 3A 20

; baud_text (0909h)
                db      "  "                                  ; 0909: 20 20

; data_090B (090Bh)
                db      "  ,"                                 ; 090B: 20 20 2C

; parity_text (090Eh)
                db      "e,"                                  ; 090E: 65 2C

; data_bits_text (0910h)
                db      "7,"                                  ; 0910: 37 2C

; stop_bits_text (0912h)
                db      "1,"                                  ; 0912: 31 2C

; retry_text (0914h)
                db      " "                                   ; 0914: 20
                db      0Dh,0Ah                               ; 0915: 0D 0A
                db      "$"                                   ; 0917: 24

; ---------------------------------------------------------------------------
; Copy a comma-separated serial setting; lowercase letters and discard spaces.
; ---------------------------------------------------------------------------

parse_serial_field:
                or      cx,cx                                ; 0918: 0B C9
                jz      loc_0937                             ; 091A: 74 1B

loc_091C:
                mov     al,es:[bx]                           ; 091C: 26 8A 07
                inc     bx                                   ; 091F: 43
                cmp     al,2Ch                               ; 0920: 3C 2C
                jz      loc_0937                             ; 0922: 74 13
                cmp     al,20h                               ; 0924: 3C 20
                jz      loc_0935                             ; 0926: 74 0D
                cmp     dx,0h                                ; 0928: 83 FA 00
                jz      loc_0935                             ; 092B: 74 08
                or      al,20h                               ; 092D: 0C 20
                mov     ds:[bp+0h],al                        ; 092F: 3E 88 46 00
                dec     dx                                   ; 0933: 4A
                inc     bp                                   ; 0934: 45

loc_0935:
                loop    loc_091C                             ; 0935: E2 E5

loc_0937:
                ret                                          ; 0937: C3

; ---------------------------------------------------------------------------
; Set/clear the persistent retry flag and patch the resident INT 14h dispatch.
; ---------------------------------------------------------------------------

set_serial_retry:
                push    es                                   ; 0938: 06
                mov     ax,0h                                ; 0939: B8 00 00
                mov     es,ax                                ; 093C: 8E C0
                mov     al,ds:[data_0906]                    ; 093E: A0 06 09
                and     al,3h                                ; 0941: 24 03
                mov     dl,es:[data_05BB]                    ; 0943: 26 8A 16 BB 05
                cmp     byte ptr ds:[retry_text],70h         ; 0948: 80 3E 14 09 70
                jnz     loc_0953                             ; 094D: 75 04
                or      dl,al                                ; 094F: 0A D0
                jmp     short loc_095C                       ; 0951: EB 09

loc_0953:
                mov     byte ptr ds:[retry_text],2Dh         ; 0953: C6 06 14 09 2D
                xor     al,0FFh                              ; 0958: 34 FF
                and     dl,al                                ; 095A: 22 D0

loc_095C:
                mov     es:[data_05BB],dl                    ; 095C: 26 88 16 BB 05
                cmp     dl,3h                                ; 0961: 80 FA 03
                jnz     loc_096F                             ; 0964: 75 09
                mov     word ptr es:[583h],5EBh              ; 0966: 26 C7 06 83 05 EB 05
                jmp     short loc_0992                       ; 096D: EB 23

loc_096F:
                cmp     dl,2h                                ; 096F: 80 FA 02
                jnz     loc_097D                             ; 0972: 75 09
                mov     word ptr es:[583h],575h              ; 0974: 26 C7 06 83 05 75 05
                jmp     short loc_0992                       ; 097B: EB 15

loc_097D:
                cmp     dl,1h                                ; 097D: 80 FA 01
                jnz     loc_098B                             ; 0980: 75 09
                mov     word ptr es:[583h],574h              ; 0982: 26 C7 06 83 05 74 05
                jmp     short loc_0992                       ; 0989: EB 07

loc_098B:
                mov     word ptr es:[583h],0EBh              ; 098B: 26 C7 06 83 05 EB 00

loc_0992:
                pop     es                                   ; 0992: 07
                ret                                          ; 0993: C3

; ---------------------------------------------------------------------------
; Select baud/parity/data/stop settings, call BIOS INT 14h, and print configuration.
; ---------------------------------------------------------------------------

configure_serial:
                mov     dx,ds:[baud_text]                    ; 0994: 8B 16 09 09
                mov     bx,baud_rate_table                   ; 0998: BB D0 08
                mov     si,0h                                ; 099B: BE 00 00
                mov     cx,8h                                ; 099E: B9 08 00

loc_09A1:
                cmp     dx,[bx+si]                           ; 09A1: 3B 10
                jnz     loc_0A1B                             ; 09A3: 75 76
                mov     ax,si                                ; 09A5: 8B C6
                mov     word ptr ds:[data_090B],3030h        ; 09A7: C7 06 0B 09 30 30
                test    ax,8h                                ; 09AD: A9 08 00
                jnz     loc_09B8                             ; 09B0: 75 06
                mov     word ptr ds:[data_090B],2030h        ; 09B2: C7 06 0B 09 30 20

loc_09B8:
                mov     cl,4h                                ; 09B8: B1 04
                shl     al,cl                                ; 09BA: D2 E0
                cmp     byte ptr ds:[parity_text],6Eh        ; 09BC: 80 3E 0E 09 6E
                jnz     loc_09C5                             ; 09C1: 75 02
                jmp     short loc_09D7                       ; 09C3: EB 12

loc_09C5:
                cmp     byte ptr ds:[parity_text],6Fh        ; 09C5: 80 3E 0E 09 6F
                jnz     loc_09D0                             ; 09CA: 75 04
                or      al,8h                                ; 09CC: 0C 08
                jmp     short loc_09D7                       ; 09CE: EB 07

loc_09D0:
                mov     byte ptr ds:[parity_text],65h        ; 09D0: C6 06 0E 09 65
                or      al,18h                               ; 09D5: 0C 18

loc_09D7:
                cmp     byte ptr ds:[stop_bits_text],32h     ; 09D7: 80 3E 12 09 32
                jnz     loc_09E2                             ; 09DC: 75 04
                or      al,4h                                ; 09DE: 0C 04
                jmp     short loc_09E7                       ; 09E0: EB 05

loc_09E2:
                mov     byte ptr ds:[stop_bits_text],31h     ; 09E2: C6 06 12 09 31

loc_09E7:
                cmp     byte ptr ds:[data_bits_text],38h     ; 09E7: 80 3E 10 09 38
                jnz     loc_09F2                             ; 09EC: 75 04
                or      al,3h                                ; 09EE: 0C 03
                jmp     short loc_09F9                       ; 09F0: EB 07

loc_09F2:
                mov     byte ptr ds:[data_bits_text],37h     ; 09F2: C6 06 10 09 37
                or      al,2h                                ; 09F7: 0C 02

loc_09F9:
                cmp     byte ptr ds:[data_0906],32h          ; 09F9: 80 3E 06 09 32
                jnz     loc_0A05                             ; 09FE: 75 05
                mov     dx,1h                                ; 0A00: BA 01 00
                jmp     short loc_0A0D                       ; 0A03: EB 08

loc_0A05:
                mov     byte ptr ds:[data_0906],31h          ; 0A05: C6 06 06 09 31
                mov     dx,0h                                ; 0A0A: BA 00 00

loc_0A0D:
                int     14h                                  ; 0A0D: CD 14
                call    set_serial_retry                     ; 0A0F: E8 26 FF
                mov     dx,data_0901                         ; 0A12: BA 01 09
                mov     ah,9h                                ; 0A15: B4 09
                int     21h                                  ; 0A17: CD 21
                jmp     short loc_0A26                       ; 0A19: EB 0B

loc_0A1B:
                inc     si                                   ; 0A1B: 46
                inc     si                                   ; 0A1C: 46
                loop    loc_09A1                             ; 0A1D: E2 82
                mov     dx,data_08E0                         ; 0A1F: BA E0 08
                mov     ah,9h                                ; 0A22: B4 09
                int     21h                                  ; 0A24: CD 21

loc_0A26:
                ret                                          ; 0A26: C3

; ---------------------------------------------------------------------------
; Validate COM1/COM2 and parse baud, parity, data bits, stop bits, and retry option.
; ---------------------------------------------------------------------------

set_serial_mode:
                cmp     byte ptr ds:[device_colon],3Ah       ; 0A27: 80 3E 0A 01 3A
                jnz     loc_0A3C                             ; 0A2C: 75 0E
                cmp     byte ptr ds:[device_number],31h      ; 0A2E: 80 3E 09 01 31
                jz      loc_0A3F                             ; 0A33: 74 0A
                cmp     byte ptr ds:[device_number],32h      ; 0A35: 80 3E 09 01 32
                jz      loc_0A3F                             ; 0A3A: 74 03

loc_0A3C:
                jmpn    loc_0AC5                             ; 0A3C: E9 86 00

loc_0A3F:
                call    install_resident                     ; 0A3F: E8 72 FC
                mov     al,ds:[device_number]                ; 0A42: A0 09 01
                mov     ds:[data_0906],al                    ; 0A45: A2 06 09
                mov     si,0h                                ; 0A48: BE 00 00
                mov     bx,81h                               ; 0A4B: BB 81 00

loc_0A4E:
                cmp     byte ptr [bx+si],20h                 ; 0A4E: 80 38 20
                jnz     loc_0A56                             ; 0A51: 75 03
                inc     si                                   ; 0A53: 46
                jmp     short loc_0A4E                       ; 0A54: EB F8

loc_0A56:
                lea     bx,[si+86h]                          ; 0A56: 8D 9C 86 00
                mov     cl,es:[command_length]               ; 0A5A: 26 8A 0E 80 00
                mov     ch,0h                                ; 0A5F: B5 00
                cmp     cx,7h                                ; 0A61: 83 F9 07
                jl      loc_0ABC                             ; 0A64: 7C 56
                sub     cx,5h                                ; 0A66: 83 E9 05
                mov     bp,909h                              ; 0A69: BD 09 09
                mov     dx,4h                                ; 0A6C: BA 04 00
                call    parse_serial_field                   ; 0A6F: E8 A6 FE
                mov     byte ptr ds:[stop_bits_text],31h     ; 0A72: C6 06 12 09 31
                mov     byte ptr ds:[parity_text],65h        ; 0A77: C6 06 0E 09 65
                mov     byte ptr ds:[data_bits_text],37h     ; 0A7C: C6 06 10 09 37
                mov     byte ptr ds:[retry_text],20h         ; 0A81: C6 06 14 09 20
                mov     ax,ds:[baud_text]                    ; 0A86: A1 09 09
                cmp     ax,3131h                             ; 0A89: 3D 31 31
                jnz     loc_0A93                             ; 0A8C: 75 05
                mov     byte ptr ds:[stop_bits_text],32h     ; 0A8E: C6 06 12 09 32

loc_0A93:
                mov     bp,90Eh                              ; 0A93: BD 0E 09
                mov     dx,1h                                ; 0A96: BA 01 00
                call    parse_serial_field                   ; 0A99: E8 7C FE
                mov     bp,910h                              ; 0A9C: BD 10 09
                mov     dx,1h                                ; 0A9F: BA 01 00
                call    parse_serial_field                   ; 0AA2: E8 73 FE
                mov     bp,912h                              ; 0AA5: BD 12 09
                mov     dx,1h                                ; 0AA8: BA 01 00
                call    parse_serial_field                   ; 0AAB: E8 6A FE
                mov     bp,914h                              ; 0AAE: BD 14 09
                mov     dx,1h                                ; 0AB1: BA 01 00
                call    parse_serial_field                   ; 0AB4: E8 61 FE
                call    configure_serial                     ; 0AB7: E8 DA FE
                jmp     short loc_0AC3                       ; 0ABA: EB 07

loc_0ABC:
                mov     dx,data_039A                         ; 0ABC: BA 9A 03
                mov     ah,9h                                ; 0ABF: B4 09
                int     21h                                  ; 0AC1: CD 21

loc_0AC3:
                jmp     short loc_0ACC                       ; 0AC3: EB 07

loc_0AC5:
                mov     dx,data_0790                         ; 0AC5: BA 90 07
                mov     ah,9h                                ; 0AC8: B4 09
                int     21h                                  ; 0ACA: CD 21

loc_0ACC:
                ret                                          ; 0ACC: C3

program         ends
                end     start
