;*-------------------------------------------------------------------------
;  COMP.ASM - PC DOS 1.10 file compare utility
;
;  Build: make comp.com     Verify: make check-utilities
;  Original: bin/comp.com, 1649 bytes; COM load address 0100h.
;  Each emitted line records its COM address and original bytes.
;  File offset = COM address - 0100h. Numeric loc_ / data_ names retain
;  addresses where a fuller semantic name has not yet been established.
;  This is an exact static mapping; runtime behavior has not been tested.
;
;  Layout:
;    0100h-0102h  code
;    01A2h-0538h  code
;  All remaining image bytes are initialized data, messages, or tables.
;  File buffers begin at 0771h, just beyond the initialized image.
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
data_005D               equ     5Dh
data_006A               equ     6Ah
data_006C               equ     6Ch
command_length          equ     80h
command_tail            equ     81h
secondary_fcb           equ     539h
data_053A               equ     53Ah
secondary_record_size   equ     547h
secondary_file_size     equ     549h
saved_source            equ     55Fh
records_per_buffer      equ     561h
secondary_buffer        equ     563h
primary_records_left    equ     565h
compare_byte_count      equ     567h
compare_flags           equ     569h
filename_input          equ     56Ah
filename_length         equ     56Bh
filename_text           equ     56Ch
file_offset_high        equ     57Ch
file_offset_low         equ     57Eh
mismatch_count          equ     580h
offset_hex_buffer       equ     581h
data_0588               equ     588h
data_0589               equ     589h
data_05AF               equ     5AFh
hex_digits              equ     5D0h
data_05E0               equ     5E0h
data_05FA               equ     5FAh
data_0606               equ     606h
data_060A               equ     60Ah
data_0614               equ     614h
data_0618               equ     618h
data_0630               equ     630h
data_0645               equ     645h
data_064C               equ     64Ch
data_065B               equ     65Bh
data_0662               equ     662h
data_066D               equ     66Dh
data_0682               equ     682h
data_0687               equ     687h
data_06A3               equ     6A3h
data_06EF               equ     6EFh
data_0713               equ     713h
data_0736               equ     736h
data_0755               equ     755h
primary_buffer          equ     771h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Jump over the copyright banner into initialization.
; ---------------------------------------------------------------------------

start:
                jmpn    init                                 ; 0100: E9 9F 00
                db      "The IBM Personal Computer File Compare U"; 0103: 40 data bytes
                db      "tility Version 1.10 (C)Copyright IBM Cor"; 012B: 40 data bytes
                db      "p 1981, 1982 Licensed Material - Program"; 0153: 40 data bytes
                db      " Property of IBM Author - David Litton "; 017B: 39 data bytes

; ---------------------------------------------------------------------------
; Validate DOS drive status and allocate two file buffers from available memory.
; ---------------------------------------------------------------------------

init:
                cld                                          ; 01A2: FC
                mov     sp,100h                              ; 01A3: BC 00 01
                or      ah,al                                ; 01A6: 0A E0
                rawop   82h,0FCh,0FFh                        ; 01A8: 82 FC FF ; cmp ah,0FFh
                jnz     loc_01B2                             ; 01AB: 75 05
                call    invalid_drive                        ; 01AD: E8 A0 02
                int     20h                                  ; 01B0: CD 20

loc_01B2:
                int     11h                                  ; 01B2: CD 11
                and     al,0C0h                              ; 01B4: 24 C0
                or      al,al                                ; 01B6: 0A C0
                jnz     loc_01BF                             ; 01B8: 75 05
                or      byte ptr ds:[compare_flags],1h       ; 01BA: 80 0E 69 05 01

loc_01BF:
                mov     si,6Ch                               ; 01BF: BE 6C 00
                mov     di,secondary_fcb                     ; 01C2: BF 39 05
                mov     cx,0Ch                               ; 01C5: B9 0C 00
                rep     movsb                                ; 01C8: F3 A4
                mov     ax,0A0h                              ; 01CA: B8 A0 00
                mov     dx,ds:[data_0002]                    ; 01CD: 8B 16 02 00
                mov     bx,ds                                ; 01D1: 8C DB
                sub     dx,bx                                ; 01D3: 2B D3
                sub     dx,80h                               ; 01D5: 81 EA 80 00
                cmp     dx,0A00h                             ; 01D9: 81 FA 00 0A
                jnc     loc_01E9                             ; 01DD: 73 0A
                shr     dx,1                                 ; 01DF: D1 EA
                shr     dx,1                                 ; 01E1: D1 EA
                shr     dx,1                                 ; 01E3: D1 EA
                shr     dx,1                                 ; 01E5: D1 EA
                mov     ax,dx                                ; 01E7: 8B C2

loc_01E9:
                mov     ds:[records_per_buffer],ax           ; 01E9: A3 61 05
                mov     cl,7h                                ; 01EC: B1 07
                shl     ax,cl                                ; 01EE: D3 E0
                mov     si,ax                                ; 01F0: 8B F0
                add     ax,771h                              ; 01F2: 05 71 07
                mov     ds:[secondary_buffer],ax             ; 01F5: A3 63 05

loc_01F8:
                rawop   82h,3Eh,5Dh,0h,20h                   ; 01F8: 82 3E 5D 00 20 ; cmp byte ptr ds:[data_005D],20h
                jnz     loc_020E                             ; 01FD: 75 0F

; ---------------------------------------------------------------------------
; Request the first filename if it was not supplied on the command line.
; ---------------------------------------------------------------------------

prompt_primary:
                mov     dx,data_0687                         ; 01FF: BA 87 06
                mov     bx,5Ch                               ; 0202: BB 5C 00
                call    read_filename                        ; 0205: E8 29 02
                cmp     al,0FFh                              ; 0208: 3C FF
                jz      prompt_primary                       ; 020A: 74 F3
                jmp     short loc_01F8                       ; 020C: EB EA

loc_020E:
                rawop   82h,3Eh,3Ah,5h,20h                   ; 020E: 82 3E 3A 05 20 ; cmp byte ptr ds:[data_053A],20h
                jnz     loc_023D                             ; 0213: 75 28
                rawop   82h,3Eh,39h,5h,0h                    ; 0215: 82 3E 39 05 00 ; cmp byte ptr ds:[secondary_fcb],0h
                jnz     loc_0232                             ; 021A: 75 16

; ---------------------------------------------------------------------------
; Request the second filename or a drive on which to find the same filename.
; ---------------------------------------------------------------------------

prompt_secondary:
                mov     dx,data_06EF                         ; 021C: BA EF 06
                mov     bx,secondary_fcb                     ; 021F: BB 39 05
                call    read_filename                        ; 0222: E8 0C 02
                cmp     al,0FFh                              ; 0225: 3C FF
                jz      prompt_secondary                     ; 0227: 74 F3
                rawop   82h,3Eh,6Ch,5h,0Dh                   ; 0229: 82 3E 6C 05 0D ; cmp byte ptr ds:[filename_text],0Dh
                jnz     loc_020E                             ; 022E: 75 DE
                jmp     short prompt_secondary               ; 0230: EB EA

loc_0232:
                mov     si,5Dh                               ; 0232: BE 5D 00
                mov     di,data_053A                         ; 0235: BF 3A 05
                mov     cx,0Bh                               ; 0238: B9 0B 00
                rep     movsb                                ; 023B: F3 A4

loc_023D:
                mov     ah,19h                               ; 023D: B4 19
                int     21h                                  ; 023F: CD 21
                inc     al                                   ; 0241: FE C0
                rawop   82h,3Eh,5Ch,0h,0h                    ; 0243: 82 3E 5C 00 00 ; cmp byte ptr ds:[data_005C],0h
                jnz     loc_024D                             ; 0248: 75 03
                mov     ds:[data_005C],al                    ; 024A: A2 5C 00

loc_024D:
                rawop   82h,3Eh,39h,5h,0h                    ; 024D: 82 3E 39 05 00 ; cmp byte ptr ds:[secondary_fcb],0h
                jnz     reject_same_file                     ; 0252: 75 03
                mov     ds:[secondary_fcb],al                ; 0254: A2 39 05

; ---------------------------------------------------------------------------
; Compare the two FCB drive/name fields and reject identical specifications.
; ---------------------------------------------------------------------------

reject_same_file:
                mov     si,5Ch                               ; 0257: BE 5C 00
                mov     di,secondary_fcb                     ; 025A: BF 39 05
                mov     cx,0Ch                               ; 025D: B9 0C 00
                repe    cmpsb                                ; 0260: F3 A6
                jnz     loc_026A                             ; 0262: 75 06
                mov     dx,data_0713                         ; 0264: BA 13 07
                jmpn    print_result                         ; 0267: E9 8C 01

loc_026A:
                test    byte ptr ds:[compare_flags],1h       ; 026A: F6 06 69 05 01
                jz      loc_0286                             ; 026F: 74 15
                mov     dx,50h                               ; 0271: BA 50 00
                mov     ds,dx                                ; 0274: 8E DA
                mov     ah,ds:[data_0004]                    ; 0276: 8A 26 04 00
                mov     dx,cs                                ; 027A: 8C CA
                mov     ds,dx                                ; 027C: 8E DA
                inc     ah                                   ; 027E: FE C4
                cmp     ah,ds:[data_005C]                    ; 0280: 3A 26 5C 00
                jnz     loc_0293                             ; 0284: 75 0D

loc_0286:
                mov     dx,data_06A3                         ; 0286: BA A3 06
                mov     ah,9h                                ; 0289: B4 09
                int     21h                                  ; 028B: CD 21
                mov     ah,0Ch                               ; 028D: B4 0C
                mov     al,1h                                ; 028F: B0 01
                int     21h                                  ; 0291: CD 21

loc_0293:
                mov     dx,5Ch                               ; 0293: BA 5C 00
                mov     word ptr ds:[data_006A],80h          ; 0296: C7 06 6A 00 80 00
                call    open_file                            ; 029C: E8 BB 01
                mov     ds:[primary_records_left],bx         ; 029F: 89 1E 65 05
                mov     ah,1Ah                               ; 02A3: B4 1A
                mov     dx,primary_buffer                    ; 02A5: BA 71 07
                int     21h                                  ; 02A8: CD 21
                mov     dx,5Ch                               ; 02AA: BA 5C 00
                call    read_primary                         ; 02AD: E8 FD 01
                mov     dx,secondary_fcb                     ; 02B0: BA 39 05
                mov     word ptr ds:[secondary_record_size],80h; 02B3: C7 06 47 05 80 00
                call    open_file                            ; 02B9: E8 9E 01
                mov     si,6Ch                               ; 02BC: BE 6C 00
                mov     di,secondary_file_size               ; 02BF: BF 49 05
                mov     cx,4h                                ; 02C2: B9 04 00
                repe    cmpsb                                ; 02C5: F3 A6
                jz      compare_buffers                      ; 02C7: 74 4E
                mov     dx,data_0736                         ; 02C9: BA 36 07
                jmpn    print_result                         ; 02CC: E9 27 01

loc_02CF:
                cmp     word ptr ds:[primary_records_left],0h; 02CF: 83 3E 65 05 00
                jz      loc_02F0                             ; 02D4: 74 1A
                test    byte ptr ds:[compare_flags],2h       ; 02D6: F6 06 69 05 02
                jz      loc_02E5                             ; 02DB: 74 08
                and     byte ptr ds:[compare_flags],0FDh     ; 02DD: 80 26 69 05 FD
                jmpn    loc_030A                             ; 02E2: E9 25 00

loc_02E5:
                or      byte ptr ds:[compare_flags],2h       ; 02E5: 80 0E 69 05 02
                call    read_secondary                       ; 02EA: E8 19 02
                jmpn    loc_030A                             ; 02ED: E9 1A 00

loc_02F0:
                test    byte ptr ds:[compare_flags],8h       ; 02F0: F6 06 69 05 08
                jz      loc_02FA                             ; 02F5: 74 03
                call    warn_missing_eof                     ; 02F7: E8 04 02

loc_02FA:
                mov     dx,data_0630                         ; 02FA: BA 30 06
                test    byte ptr ds:[compare_flags],4h       ; 02FD: F6 06 69 05 04
                jnz     loc_0307                             ; 0302: 75 03
                jmpn    print_result                         ; 0304: E9 EF 00

loc_0307:
                jmpn    finish_compare                       ; 0307: E9 F0 00

loc_030A:
                mov     dx,primary_buffer                    ; 030A: BA 71 07
                mov     ah,1Ah                               ; 030D: B4 1A
                int     21h                                  ; 030F: CD 21
                mov     dx,5Ch                               ; 0311: BA 5C 00
                call    read_primary                         ; 0314: E8 96 01

; ---------------------------------------------------------------------------
; Compare the current buffers with REPE CMPSB and track the 32-bit file offset.
; ---------------------------------------------------------------------------

compare_buffers:
                test    byte ptr ds:[compare_flags],2h       ; 0317: F6 06 69 05 02
                jnz     loc_0321                             ; 031C: 75 03
                call    read_secondary                       ; 031E: E8 E5 01

loc_0321:
                mov     cx,ds:[compare_byte_count]           ; 0321: 8B 0E 67 05
                mov     si,primary_buffer                    ; 0325: BE 71 07
                mov     di,ds:[secondary_buffer]             ; 0328: 8B 3E 63 05

loc_032C:
                jcxz    loc_0332                             ; 032C: E3 04
                repe    cmpsb                                ; 032E: F3 A6
                jnz     report_mismatch                      ; 0330: 75 18

loc_0332:
                mov     bx,ds:[file_offset_high]             ; 0332: 8B 1E 7C 05
                mov     ax,ds:[file_offset_low]              ; 0336: A1 7E 05
                add     ax,ds:[compare_byte_count]           ; 0339: 03 06 67 05
                adc     bx,0h                                ; 033D: 83 D3 00
                mov     ds:[file_offset_high],bx             ; 0340: 89 1E 7C 05
                mov     ds:[file_offset_low],ax              ; 0344: A3 7E 05
                jmpn    loc_02CF                             ; 0347: E9 85 FF

; ---------------------------------------------------------------------------
; Display both differing bytes and their file offset; stop after ten mismatches.
; ---------------------------------------------------------------------------

report_mismatch:
                or      byte ptr ds:[compare_flags],4h       ; 034A: 80 0E 69 05 04
                dec     si                                   ; 034F: 4E
                dec     di                                   ; 0350: 4F
                mov     al,[si]                              ; 0351: 8A 04
                mov     dx,data_0606                         ; 0353: BA 06 06
                call    format_hex_byte                      ; 0356: E8 C1 01
                mov     al,[di]                              ; 0359: 8A 05
                mov     dx,data_0614                         ; 035B: BA 14 06
                call    format_hex_byte                      ; 035E: E8 B9 01
                mov     bx,ds:[file_offset_high]             ; 0361: 8B 1E 7C 05
                mov     ax,si                                ; 0365: 8B C6
                sub     ax,771h                              ; 0367: 2D 71 07
                add     ax,ds:[file_offset_low]              ; 036A: 03 06 7E 05
                adc     bx,0h                                ; 036E: 83 D3 00
                mov     ds:[offset_hex_buffer],bx            ; 0371: 89 1E 81 05
                inc     si                                   ; 0375: 46
                inc     di                                   ; 0376: 47
                mov     dx,data_0588                         ; 0377: BA 88 05
                call    format_hex_byte                      ; 037A: E8 9D 01
                mov     al,ah                                ; 037D: 8A C4
                call    format_hex_byte                      ; 037F: E8 98 01
                mov     ax,ds:[offset_hex_buffer]            ; 0382: A1 81 05
                call    format_hex_byte                      ; 0385: E8 92 01
                mov     al,ah                                ; 0388: 8A C4
                call    format_hex_byte                      ; 038A: E8 8D 01
                mov     bx,cx                                ; 038D: 8B D9
                mov     ah,2h                                ; 038F: B4 02
                mov     cx,1Ah                               ; 0391: B9 1A 00
                mov     ds:[saved_source],si                 ; 0394: 89 36 5F 05
                mov     si,data_05E0                         ; 0398: BE E0 05

loc_039B:
                lodsb                                        ; 039B: AC
                mov     dl,al                                ; 039C: 8A D0
                int     21h                                  ; 039E: CD 21
                loop    loc_039B                             ; 03A0: E2 F9
                mov     si,offset_hex_buffer                 ; 03A2: BE 81 05
                mov     cx,8h                                ; 03A5: B9 08 00
                and     byte ptr ds:[compare_flags],7Fh      ; 03A8: 80 26 69 05 7F

loc_03AD:
                lodsb                                        ; 03AD: AC
                test    byte ptr ds:[compare_flags],80h      ; 03AE: F6 06 69 05 80
                jnz     loc_03BD                             ; 03B3: 75 08
                cmp     al,30h                               ; 03B5: 3C 30
                jnz     loc_03BD                             ; 03B7: 75 04
                loop    loc_03AD                             ; 03B9: E2 F2
                jcxz    loc_03C8                             ; 03BB: E3 0B

loc_03BD:
                mov     dl,al                                ; 03BD: 8A D0
                int     21h                                  ; 03BF: CD 21
                or      byte ptr ds:[compare_flags],80h      ; 03C1: 80 0E 69 05 80
                loop    loc_03AD                             ; 03C6: E2 E5

loc_03C8:
                test    byte ptr ds:[compare_flags],80h      ; 03C8: F6 06 69 05 80
                jnz     loc_03D3                             ; 03CD: 75 04
                mov     dl,30h                               ; 03CF: B2 30
                int     21h                                  ; 03D1: CD 21

loc_03D3:
                mov     cx,bx                                ; 03D3: 8B CB
                mov     si,ds:[saved_source]                 ; 03D5: 8B 36 5F 05
                mov     ah,9h                                ; 03D9: B4 09
                mov     dx,data_05FA                         ; 03DB: BA FA 05
                int     21h                                  ; 03DE: CD 21
                mov     dx,data_060A                         ; 03E0: BA 0A 06
                int     21h                                  ; 03E3: CD 21
                inc     byte ptr ds:[mismatch_count]         ; 03E5: FE 06 80 05
                rawop   82h,3Eh,80h,5h,0Ah                   ; 03E9: 82 3E 80 05 0A ; cmp byte ptr ds:[mismatch_count],0Ah
                jz      loc_03F3                             ; 03EE: 74 03
                jmpn    loc_032C                             ; 03F0: E9 39 FF

loc_03F3:
                mov     dx,data_0589                         ; 03F3: BA 89 05

; ---------------------------------------------------------------------------
; Print a result or error message at DS:DX, then finish this comparison.
; ---------------------------------------------------------------------------

print_result:
                mov     ah,9h                                ; 03F6: B4 09
                int     21h                                  ; 03F8: CD 21

; ---------------------------------------------------------------------------
; Reset flags, counts and offset before offering another comparison.
; ---------------------------------------------------------------------------

finish_compare:
                and     byte ptr ds:[compare_flags],1h       ; 03FA: 80 26 69 05 01
                mov     byte ptr ds:[mismatch_count],0h      ; 03FF: C6 06 80 05 00
                mov     word ptr ds:[file_offset_high],0h    ; 0404: C7 06 7C 05 00 00
                mov     word ptr ds:[file_offset_low],0h     ; 040A: C7 06 7E 05 00 00
                mov     word ptr ds:[secondary_fcb],2000h    ; 0410: C7 06 39 05 00 20

; ---------------------------------------------------------------------------
; Accept Y/N to compare another pair of files or exit through INT 20h.
; ---------------------------------------------------------------------------

ask_another:
                mov     dx,data_0755                         ; 0416: BA 55 07
                mov     ah,9h                                ; 0419: B4 09
                int     21h                                  ; 041B: CD 21
                mov     ax,0C01h                             ; 041D: B8 01 0C
                int     21h                                  ; 0420: CD 21
                or      al,20h                               ; 0422: 0C 20
                cmp     al,79h                               ; 0424: 3C 79
                jz      loc_042E                             ; 0426: 74 06
                cmp     al,6Eh                               ; 0428: 3C 6E
                jnz     ask_another                          ; 042A: 75 EA
                int     20h                                  ; 042C: CD 20

loc_042E:
                jmpn    prompt_primary                       ; 042E: E9 CE FD

; ---------------------------------------------------------------------------
; DX=prompt, BX=destination FCB. Read a name and parse it with DOS AX=2901h.
; ---------------------------------------------------------------------------

read_filename:
                mov     byte ptr ds:[filename_length],0h     ; 0431: C6 06 6B 05 00
                mov     ah,9h                                ; 0436: B4 09
                int     21h                                  ; 0438: CD 21
                mov     dx,filename_input                    ; 043A: BA 6A 05
                mov     ah,0Ah                               ; 043D: B4 0A
                int     21h                                  ; 043F: CD 21
                mov     si,filename_text                     ; 0441: BE 6C 05
                mov     di,bx                                ; 0444: 8B FB
                mov     ax,2901h                             ; 0446: B8 01 29
                int     21h                                  ; 0449: CD 21
                cmp     al,0FFh                              ; 044B: 3C FF
                jz      invalid_drive                        ; 044D: 74 01
                ret                                          ; 044F: C3

; ---------------------------------------------------------------------------
; Display the invalid drive error; return AL=FFh.
; ---------------------------------------------------------------------------

invalid_drive:
                mov     dx,data_05AF                         ; 0450: BA AF 05
                mov     ah,9h                                ; 0453: B4 09
                int     21h                                  ; 0455: CD 21
                mov     al,0FFh                              ; 0457: B0 FF
                ret                                          ; 0459: C3

; ---------------------------------------------------------------------------
; DX=FCB. Obtain record count, open the file and clear its random-record fields.
; ---------------------------------------------------------------------------

open_file:
                mov     si,dx                                ; 045A: 8B F2
                mov     ch,31h                               ; 045C: B5 31
                cmp     dx,5Ch                               ; 045E: 83 FA 5C
                jz      loc_0465                             ; 0461: 74 02
                mov     ch,32h                               ; 0463: B5 32

loc_0465:
                mov     ah,23h                               ; 0465: B4 23
                int     21h                                  ; 0467: CD 21
                or      al,al                                ; 0469: 0A C0
                jnz     loc_048C                             ; 046B: 75 1F
                mov     bx,[si+21h]                          ; 046D: 8B 5C 21
                or      bx,bx                                ; 0470: 0B DB
                jz      loc_0497                             ; 0472: 74 23
                mov     ah,0Fh                               ; 0474: B4 0F
                int     21h                                  ; 0476: CD 21
                cmp     al,al                                ; 0478: 3A C0
                jnz     loc_04A2                             ; 047A: 75 26
                mov     word ptr [si+20h],0h                 ; 047C: C7 44 20 00 00
                mov     word ptr [si+22h],0h                 ; 0481: C7 44 22 00 00
                mov     word ptr [si+24h],0h                 ; 0486: C7 44 24 00 00

loc_048B:
                ret                                          ; 048B: C3

loc_048C:
                pop     dx                                   ; 048C: 5A
                mov     ds:[data_064C],ch                    ; 048D: 88 2E 4C 06
                mov     dx,data_0645                         ; 0491: BA 45 06
                jmpn    print_result                         ; 0494: E9 5F FF

loc_0497:
                pop     dx                                   ; 0497: 5A
                mov     ds:[data_0662],ch                    ; 0498: 88 2E 62 06
                mov     dx,data_065B                         ; 049C: BA 5B 06
                jmpn    print_result                         ; 049F: E9 54 FF

loc_04A2:
                pop     dx                                   ; 04A2: 5A
                mov     ds:[data_0682],ch                    ; 04A3: 88 2E 82 06
                mov     dx,data_066D                         ; 04A7: BA 6D 06
                jmpn    print_result                         ; 04AA: E9 49 FF

; ---------------------------------------------------------------------------
; Read primary records with DOS AH=27h and compute the exact final byte count.
; ---------------------------------------------------------------------------

read_primary:
                mov     cx,ds:[records_per_buffer]           ; 04AD: 8B 0E 61 05
                cmp     ds:[primary_records_left],cx         ; 04B1: 39 0E 65 05
                jnc     loc_04BB                             ; 04B5: 73 04
                mov     cx,ds:[primary_records_left]         ; 04B7: 8B 0E 65 05

loc_04BB:
                mov     ah,27h                               ; 04BB: B4 27
                int     21h                                  ; 04BD: CD 21
                mov     ax,ds:[primary_records_left]         ; 04BF: A1 65 05
                sub     ax,cx                                ; 04C2: 2B C1
                mov     ds:[primary_records_left],ax         ; 04C4: A3 65 05
                mov     ax,cx                                ; 04C7: 8B C1
                mov     cl,7h                                ; 04C9: B1 07
                shl     ax,cl                                ; 04CB: D3 E0
                mov     ds:[compare_byte_count],ax           ; 04CD: A3 67 05
                cmp     word ptr ds:[primary_records_left],0h; 04D0: 83 3E 65 05 00
                jnz     loc_048B                             ; 04D5: 75 B4
                sub     ax,80h                               ; 04D7: 2D 80 00
                mov     bx,ds:[data_006C]                    ; 04DA: 8B 1E 6C 00
                and     bx,7Fh                               ; 04DE: 81 E3 7F 00
                or      bx,bx                                ; 04E2: 0B DB
                jnz     loc_04E9                             ; 04E4: 75 03
                mov     bx,80h                               ; 04E6: BB 80 00

loc_04E9:
                add     bx,ax                                ; 04E9: 03 D8
                mov     ds:[compare_byte_count],bx           ; 04EB: 89 1E 67 05
                add     bx,770h                              ; 04EF: 81 C3 70 07
                rawop   82h,3Fh,1Ah                          ; 04F3: 82 3F 1A ; cmp byte ptr [bx],1Ah
                jz      loc_048B                             ; 04F6: 74 93
                or      byte ptr ds:[compare_flags],8h       ; 04F8: 80 0E 69 05 08
                ret                                          ; 04FD: C3

; ---------------------------------------------------------------------------
; Print the missing EOF-marker warning.
; ---------------------------------------------------------------------------

warn_missing_eof:
                mov     dx,data_0618                         ; 04FE: BA 18 06
                mov     ah,9h                                ; 0501: B4 09
                int     21h                                  ; 0503: CD 21
                ret                                          ; 0505: C3

; ---------------------------------------------------------------------------
; Read a block of the secondary file into its own DTA buffer.
; ---------------------------------------------------------------------------

read_secondary:
                mov     dx,ds:[secondary_buffer]             ; 0506: 8B 16 63 05
                mov     ah,1Ah                               ; 050A: B4 1A
                int     21h                                  ; 050C: CD 21
                mov     dx,secondary_fcb                     ; 050E: BA 39 05
                mov     ah,27h                               ; 0511: B4 27
                mov     cx,ds:[records_per_buffer]           ; 0513: 8B 0E 61 05
                int     21h                                  ; 0517: CD 21
                ret                                          ; 0519: C3

; ---------------------------------------------------------------------------
; AL=byte, DX=last output position. Store two hexadecimal digits in reverse order.
; ---------------------------------------------------------------------------

format_hex_byte:
                mov     ds:[saved_source],al                 ; 051A: A2 5F 05
                mov     bx,hex_digits                        ; 051D: BB D0 05
                call    format_hex_nibble                    ; 0520: E8 0B 00
                mov     al,ds:[saved_source]                 ; 0523: A0 5F 05
                shr     al,1                                 ; 0526: D0 E8
                shr     al,1                                 ; 0528: D0 E8
                shr     al,1                                 ; 052A: D0 E8
                shr     al,1                                 ; 052C: D0 E8

; ---------------------------------------------------------------------------
; Use the hexadecimal lookup table and store a digit at DS:DX.
; ---------------------------------------------------------------------------

format_hex_nibble:
                and     al,0Fh                               ; 052E: 24 0F
                xlat                                         ; 0530: D7
                xchg    dx,bx                                ; 0531: 87 D3
                mov     [bx],al                              ; 0533: 88 07
                xchg    dx,bx                                ; 0535: 87 D3
                dec     dx                                   ; 0537: 4A
                ret                                          ; 0538: C3

; secondary_fcb (0539h)
                db      0h                                    ; 0539: 00

; data_053A (053Ah)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 053A: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h                                    ; 0546: 00

; secondary_record_size (0547h)
                db      0h,0h                                 ; 0547: 00 00

; secondary_file_size (0549h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0549: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h         ; 0555: 00 00 00 00 00 00 00 00 00 00

; saved_source (055Fh)
                db      0h,0h                                 ; 055F: 00 00

; records_per_buffer (0561h)
                db      0h,0h                                 ; 0561: 00 00

; secondary_buffer (0563h)
                db      0h,0h                                 ; 0563: 00 00

; primary_records_left (0565h)
                db      0h,0h                                 ; 0565: 00 00

; compare_byte_count (0567h)
                db      0h,2h                                 ; 0567: 00 02

; compare_flags (0569h)
                db      0h                                    ; 0569: 00

; filename_input (056Ah)
                db      10h                                   ; 056A: 10

; filename_length (056Bh)
                db      0h                                    ; 056B: 00

; filename_text (056Ch)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 056C: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h                           ; 0578: 00 00 00 00

; file_offset_high (057Ch)
                db      0h,0h                                 ; 057C: 00 00

; file_offset_low (057Eh)
                db      0h,0h                                 ; 057E: 00 00

; mismatch_count (0580h)
                db      0h                                    ; 0580: 00

; offset_hex_buffer (0581h)
                db      0h,0h,0h,0h,0h,0h,0h                  ; 0581: 00 00 00 00 00 00 00

; data_0588 (0588h)
                db      0h                                    ; 0588: 00

; data_0589 (0589h)
                db      0Dh,0Ah                               ; 0589: 0D 0A
                db      "10 Mismatches - aborting compare"    ; 058B: 32 data bytes
                db      7h,0Dh,0Ah                            ; 05AB: 07 0D 0A
                db      "$"                                   ; 05AE: 24

; data_05AF (05AFh)
                db      0Dh,0Ah                               ; 05AF: 0D 0A
                db      "Invalid drive specification"         ; 05B1: 27 data bytes
                db      7h,0Dh,0Ah                            ; 05CC: 07 0D 0A
                db      "$"                                   ; 05CF: 24

; hex_digits (05D0h)
                db      "0123456789ABCDEF"                    ; 05D0: 16 data bytes

; data_05E0 (05E0h)
                db      0Dh,0Ah                               ; 05E0: 0D 0A
                db      "Compare error at offset "            ; 05E2: 24 data bytes

; data_05FA (05FAh)
                db      0Dh,0Ah                               ; 05FA: 0D 0A
                db      "File 1 =  "                          ; 05FC: 46 69 6C 65 20 31 20 3D 20 20

; data_0606 (0606h)
                db      " "                                   ; 0606: 20
                db      0Dh,0Ah                               ; 0607: 0D 0A
                db      "$"                                   ; 0609: 24

; data_060A (060Ah)
                db      "File 2 =  "                          ; 060A: 46 69 6C 65 20 32 20 3D 20 20

; data_0614 (0614h)
                db      " "                                   ; 0614: 20
                db      0Dh,0Ah                               ; 0615: 0D 0A
                db      "$"                                   ; 0617: 24

; data_0618 (0618h)
                db      0Dh,0Ah                               ; 0618: 0D 0A
                db      "Eof mark not found"                  ; 061A: 18 data bytes
                db      7h,0Dh,0Ah                            ; 062C: 07 0D 0A
                db      "$"                                   ; 062F: 24

; data_0630 (0630h)
                db      0Dh,0Ah                               ; 0630: 0D 0A
                db      "Files compare ok"                    ; 0632: 16 data bytes
                db      0Dh,0Ah                               ; 0642: 0D 0A
                db      "$"                                   ; 0644: 24

; data_0645 (0645h)
                db      0Dh,0Ah                               ; 0645: 0D 0A
                db      "File "                               ; 0647: 46 69 6C 65 20

; data_064C (064Ch)
                db      "x not found"                         ; 064C: 78 20 6E 6F 74 20 66 6F 75 6E 64
                db      7h,0Dh,0Ah                            ; 0657: 07 0D 0A
                db      "$"                                   ; 065A: 24

; data_065B (065Bh)
                db      0Dh,0Ah                               ; 065B: 0D 0A
                db      "File "                               ; 065D: 46 69 6C 65 20

; data_0662 (0662h)
                db      "x empty"                             ; 0662: 78 20 65 6D 70 74 79
                db      7h,0Dh,0Ah                            ; 0669: 07 0D 0A
                db      "$"                                   ; 066C: 24

; data_066D (066Dh)
                db      0Dh,0Ah                               ; 066D: 0D 0A
                db      "Open error on file "                 ; 066F: 19 data bytes

; data_0682 (0682h)
                db      "x"                                   ; 0682: 78
                db      7h,0Dh,0Ah                            ; 0683: 07 0D 0A
                db      "$"                                   ; 0686: 24

; data_0687 (0687h)
                db      0Dh,0Ah                               ; 0687: 0D 0A
                db      "Enter primary file name"             ; 0689: 23 data bytes
                db      0Dh,0Ah                               ; 06A0: 0D 0A
                db      "$"                                   ; 06A2: 24

; data_06A3 (06A3h)
                db      0Dh,0Ah                               ; 06A3: 0D 0A
                db      "Insert diskette(s) with files to compare"; 06A5: 40 data bytes
                db      0Dh,0Ah                               ; 06CD: 0D 0A
                db      "and strike any key when ready"       ; 06CF: 29 data bytes
                db      0Dh,0Ah                               ; 06EC: 0D 0A
                db      "$"                                   ; 06EE: 24

; data_06EF (06EFh)
                db      0Dh,0Ah                               ; 06EF: 0D 0A
                db      "Enter 2nd file name or drive id"     ; 06F1: 31 data bytes
                db      0Dh,0Ah                               ; 0710: 0D 0A
                db      "$"                                   ; 0712: 24

; data_0713 (0713h)
                db      0Dh,0Ah                               ; 0713: 0D 0A
                db      "Cannot compare file to itself"       ; 0715: 29 data bytes
                db      7h,0Dh,0Ah                            ; 0732: 07 0D 0A
                db      "$"                                   ; 0735: 24

; data_0736 (0736h)
                db      0Dh,0Ah                               ; 0736: 0D 0A
                db      "Files are different sizes"           ; 0738: 25 data bytes
                db      7h,0Dh,0Ah                            ; 0751: 07 0D 0A
                db      "$"                                   ; 0754: 24

; data_0755 (0755h)
                db      0Dh,0Ah                               ; 0755: 0D 0A
                db      "Compare more files (Y/N)?$"          ; 0757: 26 data bytes

program         ends
                end     start
