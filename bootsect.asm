; Shared standalone boot-sector assembly; ibmboot.asm / msboot.asm select names.
program segment
        assume cs:program, ds:program
        org 0
; Preserve near jumps even when the target is in short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

; Preserve the exact far jump and CS-prefixed LODSB encodings.
; Literal boot far transfer and CS-prefixed string fetch.
jmp_far                 macro   segval, offval
                db      0EAh
                dw      offval, segval
                endm

lodsb_cs                macro
                db      2Eh,0ACh
                endm


        include fmtboot.inc
program ends
        end b_start
