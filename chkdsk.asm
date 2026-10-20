;*-------------------------------------------------------------------------
;  CHKDSK.ASM - PC DOS 1.10 disk allocation checker
;
;  Build: make chkdsk.com     Verify: make check-utilities
;  Original: bin/chkdsk.com, 1720 bytes; COM load address 0100h.
;  Each emitted line records its COM address and original bytes.
;  File offset = COM address - 0100h. Numeric loc_ / data_ names retain
;  addresses where a fuller semantic name has not yet been established.
;  This is an exact static mapping; runtime behavior has not been tested.
;
;  Layout:
;    0100h-04F5h  code
;  All remaining image bytes are initialized data, messages, or tables.
;  CHKDSK uses work_area (07B8h, beyond EOF) for runtime storage.
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
search_fcb              equ     4F6h
search_drive            equ     4FDh
data_0522               equ     522h
suppress_zeroes         equ     52Dh
data_052E               equ     52Eh
data_0536               equ     536h
data_0552               equ     552h
data_0564               equ     564h
data_057F               equ     57Fh
data_059A               equ     59Ah
data_05B6               equ     5B6h
data_05D1               equ     5D1h
data_05EB               equ     5EBh
data_0605               equ     605h
data_061F               equ     61Fh
data_062A               equ     62Ah
data_0638               equ     638h
data_0650               equ     650h
data_0660               equ     660h
data_067D               equ     67Dh
data_0693               equ     693h
data_069E               equ     69Eh
cluster_count           equ     6A2h
bytes_per_sector        equ     6A4h
sectors_per_cluster     equ     6A6h
file_count              equ     6A8h
directory_buffer        equ     6AAh
allocated_clusters      equ     6ACh
cluster_limit           equ     6AEh
deleted_files           equ     6B0h
bad_clusters            equ     6B2h
hidden_clusters         equ     6B4h
hidden_files            equ     6B6h
work_area               equ     7B8h

; ---------------------------------------------------------------------------
; Code and initialized data in original file order
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; COM entry point. DOS supplies the PSP and parsed default FCBs.
; ---------------------------------------------------------------------------

start:
                mov     sp,work_area                         ; 0100: BC B8 07
                cmp     byte ptr ds:[fcb1_name],20h          ; 0103: 80 3E 5D 00 20
                jnz     loc_0119                             ; 0108: 75 0F
                or      al,al                                ; 010A: 0A C0
                jz      check_disk                           ; 010C: 74 15

loc_010E:
                mov     dx,data_0536                         ; 010E: BA 36 05

; ---------------------------------------------------------------------------
; DX=message. Restore DS=CS, print the message, and terminate through INT 20h.
; ---------------------------------------------------------------------------

fatal_error:
                push    cs                                   ; 0111: 0E
                pop     ds                                   ; 0112: 1F
                mov     ah,9h                                ; 0113: B4 09
                int     21h                                  ; 0115: CD 21
                int     20h                                  ; 0117: CD 20

loc_0119:
                mov     dx,data_0552                         ; 0119: BA 52 05
                jmp     short fatal_error                    ; 011C: EB F3

loc_011E:
                mov     dx,data_05D1                         ; 011E: BA D1 05
                jmp     short fatal_error                    ; 0121: EB EE

; ---------------------------------------------------------------------------
; Obtain the DOS allocation table, enumerate FCB directory entries, and check chains.
; ---------------------------------------------------------------------------

check_disk:
                mov     al,ds:[fcb1_drive]                   ; 0123: A0 5C 00
                mov     ds:[search_drive],al                 ; 0126: A2 FD 04
                mov     dl,al                                ; 0129: 8A D0
                mov     ah,1Ch                               ; 012B: B4 1C
                int     21h                                  ; 012D: CD 21
                or      bx,bx                                ; 012F: 0B DB
                jz      loc_010E                             ; 0131: 74 DB
                cmp     byte ptr [bx],0F8h                   ; 0133: 80 3F F8
                jc      loc_011E                             ; 0136: 72 E6
                push    ds                                   ; 0138: 1E
                push    es                                   ; 0139: 06
                pop     ds                                   ; 013A: 1F
                mov     ds:[cluster_count],dx                ; 013B: 89 16 A2 06
                mov     ds:[bytes_per_sector],cx             ; 013F: 89 0E A4 06
                mov     ah,0h                                ; 0143: B4 00
                mov     ds:[sectors_per_cluster],ax          ; 0145: A3 A6 06
                mov     cx,dx                                ; 0148: 8B CA
                mov     di,work_area                         ; 014A: BF B8 07
                xor     ax,ax                                ; 014D: 33 C0
                rep     stosw                                ; 014F: F3 AB
                mov     cx,ax                                ; 0151: 8B C8
                mov     ds:[allocated_clusters],ax           ; 0153: A3 AC 06
                mov     ds:[file_count],ax                   ; 0156: A3 A8 06
                mov     ds:[deleted_files],ax                ; 0159: A3 B0 06
                mov     ds:[bad_clusters],ax                 ; 015C: A3 B2 06
                mov     ds:[hidden_clusters],ax              ; 015F: A3 B4 06
                mov     ds:[hidden_files],ax                 ; 0162: A3 B6 06
                mov     bp,di                                ; 0165: 8B EF
                mov     ds:[directory_buffer],bp             ; 0167: 89 2E AA 06
                mov     dx,di                                ; 016B: 8B D7
                mov     ah,1Ah                               ; 016D: B4 1A
                int     21h                                  ; 016F: CD 21
                mov     ah,11h                               ; 0171: B4 11
                mov     dx,search_fcb                        ; 0173: BA F6 04
                int     21h                                  ; 0176: CD 21
                inc     al                                   ; 0178: FE C0
                pop     es                                   ; 017A: 07
                jnz     loc_0180                             ; 017B: 75 03
                jmpn    loc_0300                             ; 017D: E9 80 01

loc_0180:
                inc     cx                                   ; 0180: 41
                add     di,2Ch                               ; 0181: 83 C7 2C
                mov     dx,di                                ; 0184: 8B D7
                mov     ah,1Ah                               ; 0186: B4 1A
                int     21h                                  ; 0188: CD 21
                mov     ah,12h                               ; 018A: B4 12
                mov     dx,search_fcb                        ; 018C: BA F6 04
                int     21h                                  ; 018F: CD 21
                inc     al                                   ; 0191: FE C0
                jnz     loc_0180                             ; 0193: 75 EB
                mov     ds:[file_count],cx                   ; 0195: 89 0E A8 06
                mov     cx,1h                                ; 0199: B9 01 00
                mov     dx,ds:[cluster_count]                ; 019C: 8B 16 A2 06
                inc     dx                                   ; 01A0: 42
                mov     ds:[cluster_limit],dx                ; 01A1: 89 16 AE 06
                add     bp,22h                               ; 01A5: 83 C5 22

loc_01A8:
                xor     ax,ax                                ; 01A8: 33 C0
                mov     si,[bp+0h]                           ; 01AA: 8B 76 00
                cmp     si,ds:[cluster_limit]                ; 01AD: 3B 36 AE 06
                mov     di,data_057F                         ; 01B1: BF 7F 05
                ja      loc_01DE                             ; 01B4: 77 28
                or      si,si                                ; 01B6: 0B F6
                jz      loc_01D2                             ; 01B8: 74 18

loc_01BA:
                mov     di,cx                                ; 01BA: 8B F9
                shl     si,1                                 ; 01BC: D1 E6
                xchg    di,[si+7B4h]                         ; 01BE: 87 BC B4 07
                shr     si,1                                 ; 01C2: D1 EE
                or      di,di                                ; 01C4: 0B FF
                jnz     loc_0207                             ; 01C6: 75 3F
                inc     ax                                   ; 01C8: 40
                call    get_fat12_entry                      ; 01C9: E8 12 02
                jz      loc_022F                             ; 01CC: 74 61
                cmp     di,0FF8h                             ; 01CE: 81 FF F8 0F

loc_01D2:
                jnc     loc_024A                             ; 01D2: 73 76
                cmp     di,ds:[cluster_limit]                ; 01D4: 3B 3E AE 06
                ja      loc_022F                             ; 01D8: 77 55
                mov     si,di                                ; 01DA: 8B F7
                jmp     short loc_01BA                       ; 01DC: EB DC

loc_01DE:
                push    ax                                   ; 01DE: 50
                mov     [bp+2h],ax                           ; 01DF: 89 46 02
                mov     [bp+4h],ax                           ; 01E2: 89 46 04
                mov     ax,cx                                ; 01E5: 8B C1
                mov     dx,2Ch                               ; 01E7: BA 2C 00
                dec     ax                                   ; 01EA: 48
                mul     dx                                   ; 01EB: F7 E2
                mov     dx,ax                                ; 01ED: 8B D0
                add     dx,ds:[directory_buffer]             ; 01EF: 03 16 AA 06
                mov     ah,13h                               ; 01F3: B4 13
                int     21h                                  ; 01F5: CD 21
                or      al,al                                ; 01F7: 0A C0
                jz      loc_01FE                             ; 01F9: 74 03
                jmpn    loc_011E                             ; 01FB: E9 20 FF

loc_01FE:
                inc     word ptr ds:[deleted_files]          ; 01FE: FF 06 B0 06
                mov     dx,data_057F                         ; 0202: BA 7F 05
                jmp     short loc_0239                       ; 0205: EB 32

loc_0207:
                mov     dx,data_059A                         ; 0207: BA 9A 05
                push    ax                                   ; 020A: 50
                mov     ah,9h                                ; 020B: B4 09
                int     21h                                  ; 020D: CD 21
                mov     ax,di                                ; 020F: 8B C7
                call    print_filename                       ; 0211: E8 B7 02
                mov     dx,data_052E                         ; 0214: BA 2E 05
                mov     ah,9h                                ; 0217: B4 09
                int     21h                                  ; 0219: CD 21
                mov     ax,cx                                ; 021B: 8B C1
                call    print_filename                       ; 021D: E8 AB 02
                mov     dx,data_069E                         ; 0220: BA 9E 06
                mov     ah,9h                                ; 0223: B4 09
                int     21h                                  ; 0225: CD 21
                pop     ax                                   ; 0227: 58
                add     ds:[allocated_clusters],ax           ; 0228: 01 06 AC 06
                jmpn    loc_02F3                             ; 022C: E9 C4 00

loc_022F:
                mov     dx,0FFFh                             ; 022F: BA FF 0F
                call    set_fat12_entry                      ; 0232: E8 C5 01
                mov     dx,data_0564                         ; 0235: BA 64 05
                push    ax                                   ; 0238: 50

loc_0239:
                mov     ah,9h                                ; 0239: B4 09
                int     21h                                  ; 023B: CD 21
                mov     ax,cx                                ; 023D: 8B C1
                call    print_filename                       ; 023F: E8 89 02
                mov     dx,data_069E                         ; 0242: BA 9E 06
                mov     ah,9h                                ; 0245: B4 09
                int     21h                                  ; 0247: CD 21
                pop     ax                                   ; 0249: 58

loc_024A:
                push    cx                                   ; 024A: 51
                cmp     byte ptr [bp-0Fh],0h                 ; 024B: 80 7E F1 00
                jz      loc_027B                             ; 024F: 74 2A
                push    ax                                   ; 0251: 50
                mov     si,bp                                ; 0252: 8B F5
                sub     si,1Ah                               ; 0254: 83 EE 1A
                mov     di,data_0522                         ; 0257: BF 22 05
                mov     cx,0Bh                               ; 025A: B9 0B 00

loc_025D:
                lodsb                                        ; 025D: AC
                cmp     al,[di]                              ; 025E: 3A 05
                jz      loc_0264                             ; 0260: 74 02
                jmp     short loc_0272                       ; 0262: EB 0E

loc_0264:
                inc     di                                   ; 0264: 47
                loop    loc_025D                             ; 0265: E2 F6
                pop     ax                                   ; 0267: 58
                add     ds:[bad_clusters],ax                 ; 0268: 01 06 B2 06
                dec     word ptr ds:[file_count]             ; 026C: FF 0E A8 06
                jmp     short loc_027B                       ; 0270: EB 09

loc_0272:
                pop     ax                                   ; 0272: 58
                add     ds:[hidden_clusters],ax              ; 0273: 01 06 B4 06
                inc     word ptr ds:[hidden_files]           ; 0277: FF 06 B6 06

loc_027B:
                add     ds:[allocated_clusters],ax           ; 027B: 01 06 AC 06
                mov     si,ax                                ; 027F: 8B F0
                mov     ax,[bp+2h]                           ; 0281: 8B 46 02
                mov     dx,[bp+4h]                           ; 0284: 8B 56 04
                mov     cx,ds:[sectors_per_cluster]          ; 0287: 8B 0E A6 06
                dec     cx                                   ; 028B: 49
                add     ax,cx                                ; 028C: 03 C1
                adc     dx,0h                                ; 028E: 83 D2 00
                inc     cx                                   ; 0291: 41

loc_0292:
                shr     cx,1                                 ; 0292: D1 E9
                jc      loc_029C                             ; 0294: 72 06
                shr     dx,1                                 ; 0296: D1 EA
                rcr     ax,1                                 ; 0298: D1 D8
                jmp     short loc_0292                       ; 029A: EB F6

loc_029C:
                cmp     dx,ds:[bytes_per_sector]             ; 029C: 3B 16 A4 06
                jnl     loc_02AF                             ; 02A0: 7D 0D
                div     word ptr ds:[bytes_per_sector]       ; 02A2: F7 36 A4 06
                or      dx,dx                                ; 02A6: 0B D2
                jz      loc_02AB                             ; 02A8: 74 01
                inc     ax                                   ; 02AA: 40

loc_02AB:
                cmp     ax,si                                ; 02AB: 3B C6
                jz      loc_02F2                             ; 02AD: 74 43

loc_02AF:
                xor     di,di                                ; 02AF: 33 FF
                mov     cx,ds:[sectors_per_cluster]          ; 02B1: 8B 0E A6 06
                call    scale_cluster_bytes                  ; 02B5: E8 70 01
                mov     [bp+6h],si                           ; 02B8: 89 76 06
                mov     [bp+8h],di                           ; 02BB: 89 7E 08
                mov     dx,bp                                ; 02BE: 8B D5
                sub     dx,22h                               ; 02C0: 83 EA 22
                mov     ah,0Fh                               ; 02C3: B4 0F
                int     21h                                  ; 02C5: CD 21
                or      al,al                                ; 02C7: 0A C0
                jz      loc_02CE                             ; 02C9: 74 03
                jmpn    loc_011E                             ; 02CB: E9 50 FE

loc_02CE:
                mov     ax,ds:[bytes_per_sector]             ; 02CE: A1 A4 06
                mov     [bp-0Dh],ax                          ; 02D1: 89 46 F3
                mov     cx,0h                                ; 02D4: B9 00 00
                mov     ah,28h                               ; 02D7: B4 28
                int     21h                                  ; 02D9: CD 21
                mov     ah,10h                               ; 02DB: B4 10
                int     21h                                  ; 02DD: CD 21
                mov     dx,data_05B6                         ; 02DF: BA B6 05
                mov     ah,9h                                ; 02E2: B4 09
                int     21h                                  ; 02E4: CD 21
                pop     ax                                   ; 02E6: 58
                push    ax                                   ; 02E7: 50
                call    print_filename                       ; 02E8: E8 E0 01
                mov     dx,data_069E                         ; 02EB: BA 9E 06
                mov     ah,9h                                ; 02EE: B4 09
                int     21h                                  ; 02F0: CD 21

loc_02F2:
                pop     cx                                   ; 02F2: 59

loc_02F3:
                add     bp,2Ch                               ; 02F3: 83 C5 2C
                inc     cx                                   ; 02F6: 41
                cmp     cx,ds:[file_count]                   ; 02F7: 3B 0E A8 06
                ja      loc_0300                             ; 02FB: 77 03
                jmpn    loc_01A8                             ; 02FD: E9 A8 FE

loc_0300:
                xor     ax,ax                                ; 0300: 33 C0
                mov     bp,7B8h                              ; 0302: BD B8 07
                mov     si,2h                                ; 0305: BE 02 00
                mov     cx,ds:[cluster_count]                ; 0308: 8B 0E A2 06

loc_030C:
                test    word ptr [bp+0h],0FFFFh              ; 030C: F7 46 00 FF FF
                jnz     loc_032E                             ; 0311: 75 1B
                call    get_fat12_entry                      ; 0313: E8 C8 00
                jz      loc_032E                             ; 0316: 74 16
                cmp     di,0FF7h                             ; 0318: 81 FF F7 0F
                jnz     loc_0328                             ; 031C: 75 0A
                inc     word ptr ds:[bad_clusters]           ; 031E: FF 06 B2 06
                inc     word ptr ds:[allocated_clusters]     ; 0322: FF 06 AC 06
                jmp     short loc_032E                       ; 0326: EB 06

loc_0328:
                xor     dx,dx                                ; 0328: 33 D2
                call    set_fat12_entry                      ; 032A: E8 CD 00
                inc     ax                                   ; 032D: 40

loc_032E:
                inc     bp                                   ; 032E: 45
                inc     bp                                   ; 032F: 45
                inc     si                                   ; 0330: 46
                loop    loc_030C                             ; 0331: E2 D9
                or      ax,ax                                ; 0333: 0B C0
                jz      loc_033D                             ; 0335: 74 06
                mov     bx,data_05EB                         ; 0337: BB EB 05
                call    print_cluster_bytes                  ; 033A: E8 FC 00

loc_033D:
                mov     dx,data_069E                         ; 033D: BA 9E 06
                mov     ah,9h                                ; 0340: B4 09
                int     21h                                  ; 0342: CD 21
                mov     ax,ds:[cluster_count]                ; 0344: A1 A2 06
                mov     bx,data_0605                         ; 0347: BB 05 06
                call    print_cluster_bytes                  ; 034A: E8 EC 00
                cmp     word ptr ds:[hidden_clusters],0h     ; 034D: 83 3E B4 06 00
                jz      loc_0369                             ; 0352: 74 15
                mov     ax,ds:[hidden_clusters]              ; 0354: A1 B4 06
                mov     bx,data_061F                         ; 0357: BB 1F 06
                call    print_cluster_bytes                  ; 035A: E8 DC 00
                mov     si,ds:[hidden_files]                 ; 035D: 8B 36 B6 06
                xor     di,di                                ; 0361: 33 FF
                mov     bx,data_0650                         ; 0363: BB 50 06
                call    print_count                          ; 0366: E8 C9 00

loc_0369:
                mov     ax,ds:[allocated_clusters]           ; 0369: A1 AC 06
                sub     ax,ds:[hidden_clusters]              ; 036C: 2B 06 B4 06
                sub     ax,ds:[bad_clusters]                 ; 0370: 2B 06 B2 06
                cmp     ax,0h                                ; 0374: 3D 00 00
                jz      loc_0393                             ; 0377: 74 1A
                mov     bx,data_061F                         ; 0379: BB 1F 06
                call    print_cluster_bytes                  ; 037C: E8 BA 00
                mov     si,ds:[file_count]                   ; 037F: 8B 36 A8 06
                sub     si,ds:[deleted_files]                ; 0383: 2B 36 B0 06
                sub     si,ds:[hidden_files]                 ; 0387: 2B 36 B6 06
                xor     di,di                                ; 038B: 33 FF
                mov     bx,data_062A                         ; 038D: BB 2A 06
                call    print_count                          ; 0390: E8 9F 00

loc_0393:
                cmp     word ptr ds:[bad_clusters],0h        ; 0393: 83 3E B2 06 00
                jz      loc_03A3                             ; 0398: 74 09
                mov     ax,ds:[bad_clusters]                 ; 039A: A1 B2 06
                mov     bx,data_0638                         ; 039D: BB 38 06
                call    print_cluster_bytes                  ; 03A0: E8 96 00

loc_03A3:
                mov     ax,ds:[cluster_count]                ; 03A3: A1 A2 06
                sub     ax,ds:[allocated_clusters]           ; 03A6: 2B 06 AC 06
                mov     bx,data_0660                         ; 03AA: BB 60 06
                call    print_cluster_bytes                  ; 03AD: E8 89 00
                mov     ax,ds:[psp_end_segment]              ; 03B0: A1 02 00
                mov     dx,10h                               ; 03B3: BA 10 00
                mul     dx                                   ; 03B6: F7 E2
                mov     si,ax                                ; 03B8: 8B F0
                mov     di,dx                                ; 03BA: 8B FA
                mov     bx,data_067D                         ; 03BC: BB 7D 06
                call    print_number                         ; 03BF: E8 86 00
                mov     ax,ds:[psp_end_segment]              ; 03C2: A1 02 00
                mov     dx,cs                                ; 03C5: 8C CA
                sub     ax,dx                                ; 03C7: 2B C2
                mov     dx,10h                               ; 03C9: BA 10 00
                mul     dx                                   ; 03CC: F7 E2
                mov     si,ax                                ; 03CE: 8B F0
                mov     di,dx                                ; 03D0: 8B FA
                mov     bx,data_0693                         ; 03D2: BB 93 06
                call    print_number                         ; 03D5: E8 70 00
                mov     ah,0Dh                               ; 03D8: B4 0D
                int     21h                                  ; 03DA: CD 21
                int     20h                                  ; 03DC: CD 20

; ---------------------------------------------------------------------------
; ES:BX=FAT, SI=cluster. Return the 12-bit FAT entry in DI; ZF reflects the result.
; ---------------------------------------------------------------------------

get_fat12_entry:
                mov     di,si                                ; 03DE: 8B FE
                shr     di,1                                 ; 03E0: D1 EF
                add     di,si                                ; 03E2: 03 FE
                mov     di,es:[bx+di]                        ; 03E4: 26 8B 39
                test    si,1h                                ; 03E7: F7 C6 01 00
                jz      loc_03F5                             ; 03EB: 74 08
                shr     di,1                                 ; 03ED: D1 EF
                shr     di,1                                 ; 03EF: D1 EF
                shr     di,1                                 ; 03F1: D1 EF
                shr     di,1                                 ; 03F3: D1 EF

loc_03F5:
                and     di,0FFFh                             ; 03F5: 81 E7 FF 0F
                ret                                          ; 03F9: C3

; ---------------------------------------------------------------------------
; ES:BX=FAT, SI=cluster, DX=value. Update a packed FAT12 entry and mark FAT dirty.
; ---------------------------------------------------------------------------

set_fat12_entry:
                mov     byte ptr es:[bx-1h],1h               ; 03FA: 26 C6 47 FF 01
                push    si                                   ; 03FF: 56
                mov     di,si                                ; 0400: 8B FE
                shr     si,1                                 ; 0402: D1 EE
                add     si,bx                                ; 0404: 03 F3
                add     si,di                                ; 0406: 03 F7
                shr     di,1                                 ; 0408: D1 EF
                mov     di,es:[si]                           ; 040A: 26 8B 3C
                jnc     loc_041D                             ; 040D: 73 0E
                shl     dx,1                                 ; 040F: D1 E2
                shl     dx,1                                 ; 0411: D1 E2
                shl     dx,1                                 ; 0413: D1 E2
                shl     dx,1                                 ; 0415: D1 E2
                and     di,0Fh                               ; 0417: 81 E7 0F 00
                jmp     short loc_0421                       ; 041B: EB 04

loc_041D:
                and     di,0F000h                            ; 041D: 81 E7 00 F0

loc_0421:
                or      di,dx                                ; 0421: 0B FA
                mov     es:[si],di                           ; 0423: 26 89 3C
                pop     si                                   ; 0426: 5E

loc_0427:
                ret                                          ; 0427: C3

; ---------------------------------------------------------------------------
; Multiply DI:SI by the power of two in CX using shifts; destroys CX.
; ---------------------------------------------------------------------------

scale_cluster_bytes:
                shr     cx,1                                 ; 0428: D1 E9
                jc      loc_0427                             ; 042A: 72 FB
                shl     si,1                                 ; 042C: D1 E6
                rcl     di,1                                 ; 042E: D1 D7
                jmp     short scale_cluster_bytes            ; 0430: EB F6

; ---------------------------------------------------------------------------
; DI:SI=count, BX=message. Print a count with leading zeroes suppressed.
; ---------------------------------------------------------------------------

print_count:
                mov     byte ptr ds:[suppress_zeroes],1h     ; 0432: C6 06 2D 05 01
                jmp     short print_number                   ; 0437: EB 0F

; ---------------------------------------------------------------------------
; AX=clusters, BX=message. Convert clusters to bytes using the saved geometry.
; ---------------------------------------------------------------------------

print_cluster_bytes:
                mul     word ptr ds:[bytes_per_sector]       ; 0439: F7 26 A4 06
                mov     cx,ds:[sectors_per_cluster]          ; 043D: 8B 0E A6 06
                mov     si,ax                                ; 0441: 8B F0
                mov     di,dx                                ; 0443: 8B FA
                call    scale_cluster_bytes                  ; 0445: E8 E0 FF

; ---------------------------------------------------------------------------
; DI:SI=unsigned 32-bit value, BX=message. Convert to packed BCD and print.
; ---------------------------------------------------------------------------

print_number:
                push    bx                                   ; 0448: 53
                xor     ax,ax                                ; 0449: 33 C0
                mov     bx,ax                                ; 044B: 8B D8
                mov     bp,ax                                ; 044D: 8B E8
                mov     cx,20h                               ; 044F: B9 20 00

loc_0452:
                shl     si,1                                 ; 0452: D1 E6
                rcl     di,1                                 ; 0454: D1 D7
                xchg    ax,bp                                ; 0456: 95
                call    bcd_double                           ; 0457: E8 66 00
                xchg    ax,bp                                ; 045A: 95
                xchg    ax,bx                                ; 045B: 93
                call    bcd_double                           ; 045C: E8 61 00
                xchg    ax,bx                                ; 045F: 93
                adc     al,0h                                ; 0460: 14 00
                loop    loc_0452                             ; 0462: E2 EE
                mov     cx,1310h                             ; 0464: B9 10 13
                cmp     byte ptr ds:[suppress_zeroes],0h     ; 0467: 80 3E 2D 05 00
                jnz     loc_0479                             ; 046C: 75 0B
                mov     cx,1810h                             ; 046E: B9 10 18
                xchg    ax,dx                                ; 0471: 92
                call    print_digit                          ; 0472: E8 2A 00
                xchg    ax,bx                                ; 0475: 93
                call    print_bcd_word                       ; 0476: E8 10 00

loc_0479:
                mov     ax,bp                                ; 0479: 8B C5
                call    print_bcd_word                       ; 047B: E8 0B 00
                mov     byte ptr ds:[suppress_zeroes],0h     ; 047E: C6 06 2D 05 00
                pop     dx                                   ; 0483: 5A
                mov     ah,9h                                ; 0484: B4 09
                int     21h                                  ; 0486: CD 21

loc_0488:
                ret                                          ; 0488: C3

; ---------------------------------------------------------------------------
; AX=packed BCD word. Print its four digits using the shared digit routine.
; ---------------------------------------------------------------------------

print_bcd_word:
                push    ax                                   ; 0489: 50
                mov     dl,ah                                ; 048A: 8A D4
                call    print_bcd_byte                       ; 048C: E8 01 00
                pop     dx                                   ; 048F: 5A

; ---------------------------------------------------------------------------
; DL=packed BCD byte. Print its two digits.
; ---------------------------------------------------------------------------

print_bcd_byte:
                mov     dh,dl                                ; 0490: 8A F2
                shr     dl,1                                 ; 0492: D0 EA
                shr     dl,1                                 ; 0494: D0 EA
                shr     dl,1                                 ; 0496: D0 EA
                shr     dl,1                                 ; 0498: D0 EA
                call    print_digit                          ; 049A: E8 02 00
                mov     dl,dh                                ; 049D: 8A D6

; ---------------------------------------------------------------------------
; DL low nibble=digit; CH/CL track leading positions and zero suppression.
; ---------------------------------------------------------------------------

print_digit:
                and     dl,0Fh                               ; 049F: 80 E2 0F
                jz      loc_04A6                             ; 04A2: 74 02
                mov     cl,0h                                ; 04A4: B1 00

loc_04A6:
                dec     ch                                   ; 04A6: FE CD
                and     cl,ch                                ; 04A8: 22 CD
                or      dl,30h                               ; 04AA: 80 CA 30
                sub     dl,cl                                ; 04AD: 2A D1
                cmp     byte ptr ds:[suppress_zeroes],0h     ; 04AF: 80 3E 2D 05 00
                jz      loc_04BB                             ; 04B4: 74 05
                cmp     dl,30h                               ; 04B6: 80 FA 30
                jl      loc_0488                             ; 04B9: 7C CD

loc_04BB:
                mov     ah,2h                                ; 04BB: B4 02
                int     21h                                  ; 04BD: CD 21
                ret                                          ; 04BF: C3

; ---------------------------------------------------------------------------
; Double packed BCD AX with incoming carry, using ADC/DAA on each byte.
; ---------------------------------------------------------------------------

bcd_double:
                adc     al,al                                ; 04C0: 12 C0
                daa                                          ; 04C2: 27
                xchg    al,ah                                ; 04C3: 86 C4
                adc     al,al                                ; 04C5: 12 C0
                daa                                          ; 04C7: 27
                xchg    al,ah                                ; 04C8: 86 C4
                ret                                          ; 04CA: C3

; ---------------------------------------------------------------------------
; AX=one-based directory entry number. Print the saved 8.3 filename; preserve CX.
; ---------------------------------------------------------------------------

print_filename:
                push    cx                                   ; 04CB: 51
                dec     ax                                   ; 04CC: 48
                mov     cx,2Ch                               ; 04CD: B9 2C 00
                mul     cx                                   ; 04D0: F7 E1
                mov     si,ax                                ; 04D2: 8B F0
                add     si,ds:[directory_buffer]             ; 04D4: 03 36 AA 06
                add     si,8h                                ; 04D8: 83 C6 08
                mov     cx,8h                                ; 04DB: B9 08 00
                mov     ah,2h                                ; 04DE: B4 02
                call    print_name_chars                     ; 04E0: E8 0B 00
                mov     dl,20h                               ; 04E3: B2 20
                int     21h                                  ; 04E5: CD 21
                mov     cl,3h                                ; 04E7: B1 03
                call    print_name_chars                     ; 04E9: E8 02 00
                pop     cx                                   ; 04EC: 59
                ret                                          ; 04ED: C3

; ---------------------------------------------------------------------------
; DS:SI=name bytes, CX=count, AH=02h. Print characters with DOS INT 21h.
; ---------------------------------------------------------------------------

print_name_chars:
                lodsb                                        ; 04EE: AC
                mov     dl,al                                ; 04EF: 8A D0
                int     21h                                  ; 04F1: CD 21
                loop    print_name_chars                     ; 04F3: E2 F9
                ret                                          ; 04F5: C3

; search_fcb (04F6h)
                db      0FFh,0h,0h,0h,0h,0h,6h                ; 04F6: FF 00 00 00 00 00 06

; search_drive (04FDh)
                db      0h                                    ; 04FD: 00
                db      "???????????"                         ; 04FE: 3F 3F 3F 3F 3F 3F 3F 3F 3F 3F 3F
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0509: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0515: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h                                    ; 0521: 00

; data_0522 (0522h)
                db      "badtrack   "                         ; 0522: 62 61 64 74 72 61 63 6B 20 20 20

; suppress_zeroes (052Dh)
                db      0h                                    ; 052D: 00

; data_052E (052Eh)
                db      "  and  $"                            ; 052E: 20 20 61 6E 64 20 20 24

; data_0536 (0536h)
                db      "Invalid drive specification$"        ; 0536: 28 data bytes

; data_0552 (0552h)
                db      "Invalid parameter$"                  ; 0552: 18 data bytes

; data_0564 (0564h)
                db      "Allocation error for file $"         ; 0564: 27 data bytes

; data_057F (057Fh)
                db      "Directory error-file :    $"         ; 057F: 27 data bytes

; data_059A (059Ah)
                db      "Files cross-linked: "                ; 059A: 20 data bytes
                db      0Dh,0Ah                               ; 05AE: 0D 0A
                db      "     $"                              ; 05B0: 20 20 20 20 20 24

; data_05B6 (05B6h)
                db      "File size error for file  $"         ; 05B6: 27 data bytes

; data_05D1 (05D1h)
                db      "Diskette not initialized $"          ; 05D1: 26 data bytes

; data_05EB (05EBh)
                db      " bytes disk space freed"             ; 05EB: 23 data bytes
                db      0Dh,0Ah                               ; 0602: 0D 0A
                db      "$"                                   ; 0604: 24

; data_0605 (0605h)
                db      " bytes total disk space"             ; 0605: 23 data bytes
                db      0Dh,0Ah                               ; 061C: 0D 0A
                db      "$"                                   ; 061E: 24

; data_061F (061Fh)
                db      " bytes in $"                         ; 061F: 20 62 79 74 65 73 20 69 6E 20 24

; data_062A (062Ah)
                db      " user files"                         ; 062A: 20 75 73 65 72 20 66 69 6C 65 73
                db      0Dh,0Ah                               ; 0635: 0D 0A
                db      "$"                                   ; 0637: 24

; data_0638 (0638h)
                db      " bytes in bad sectors"               ; 0638: 21 data bytes
                db      0Dh,0Ah                               ; 064D: 0D 0A
                db      "$"                                   ; 064F: 24

; data_0650 (0650h)
                db      " hidden files"                       ; 0650: 13 data bytes
                db      0Dh,0Ah                               ; 065D: 0D 0A
                db      "$"                                   ; 065F: 24

; data_0660 (0660h)
                db      " bytes available on disk"            ; 0660: 24 data bytes
                db      0Dh,0Ah,0Dh,0Ah                       ; 0678: 0D 0A 0D 0A
                db      "$"                                   ; 067C: 24

; data_067D (067Dh)
                db      " bytes total memory"                 ; 067D: 19 data bytes
                db      0Dh,0Ah                               ; 0690: 0D 0A
                db      "$"                                   ; 0692: 24

; data_0693 (0693h)
                db      " bytes free"                         ; 0693: 20 62 79 74 65 73 20 66 72 65 65

; data_069E (069Eh)
                db      0Dh,0Ah                               ; 069E: 0D 0A
                db      "$"                                   ; 06A0: 24
                db      0h                                    ; 06A1: 00

; cluster_count (06A2h)
                db      0h,0h                                 ; 06A2: 00 00

; bytes_per_sector (06A4h)
                db      0h,0h                                 ; 06A4: 00 00

; sectors_per_cluster (06A6h)
                db      0h,0h                                 ; 06A6: 00 00

; file_count (06A8h)
                db      0h,0h                                 ; 06A8: 00 00

; directory_buffer (06AAh)
                db      0h,0h                                 ; 06AA: 00 00

; allocated_clusters (06ACh)
                db      0h,0h                                 ; 06AC: 00 00

; cluster_limit (06AEh)
                db      0h,0h                                 ; 06AE: 00 00

; deleted_files (06B0h)
                db      0h,0h                                 ; 06B0: 00 00

; bad_clusters (06B2h)
                db      0h,0h                                 ; 06B2: 00 00

; hidden_clusters (06B4h)
                db      0h,0h                                 ; 06B4: 00 00

; hidden_files (06B6h)
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06B6: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06C2: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06CE: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06DA: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06E6: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06F2: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 06FE: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 070A: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0716: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0722: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 072E: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 073A: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0746: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0752: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 075E: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 076A: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0776: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 0782: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 078E: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 079A: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h   ; 07A6: 00 00 00 00 00 00 00 00 00 00 00 00
                db      0h,0h,0h,0h,0h,0h                     ; 07B2: 00 00 00 00 00 00

program         ends
                end     start
