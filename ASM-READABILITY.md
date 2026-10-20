# Assembly readability cleanup

DISKCOPY, DISKCOMP, MODE, COMP and the shared IBM/Microsoft FORMAT source have been revised toward the EDLIN source style. FILCOM is untouched.

- Every `loc_XXXX` branch in the five requested sources now has a purpose-based name. Examples are `prompt_initial_second`, `buffer_first_diskette`, `compare_second_diskette`, `read_track_failed`, `read_next_primary`, and `write_boot_image`.
- Every referenced in-image data symbol now has a real typed `LABEL BYTE` or `LABEL WORD` declaration beside its storage. Message pointers use `OFFSET`. PSP fields, BIOS memory and relocated handler addresses remain explicit external equates; they are not falsely declared as COM-image storage.
- Address/byte listing comments have moved out of these source files. Comments explain buffer ownership, cylinder/head transitions, retries, shared PSP storage, FCB record sizes, EOF checks, timestamp preservation, resident handler patches and boot geometry.
- Opaque `rawop` calls have been replaced by mnemonic encoding macros such as `cmp82_ch cylinder_limit` and `cmp82_mem read_retries,4h`. The original 82h encodings remain intact. The boot loader uses named far-transfer/string-fetch macros.
- Reused storage has phase-specific names: `second_drive` replaces the misleading `fcb1_name` at disk I/O call sites, while FORMAT distinguishes `drive_arg_seen` from `space_counted` even though both share one byte.

## Example: DISKCOMP buffer flow

```asm
prompt_initial_second:
                call    prompt_second

; Fill the large buffer from the first disk and remember its exclusive
; ending cylinder.
buffer_first_diskette:
                mov     es,word ptr ds:[bulk_buffer_segment]
                mov     word ptr ds:[bulk_compare_segment],es
                mov     dl,ds:[first_drive]
                mov     dh,ds:[cylinders_per_buffer]
                call    read_tracks
```

The small-buffer path documents that it reads two single-sided cylinders or one double-sided cylinder, then compares the resulting 8 KiB span with its corresponding part of the large buffer. The end cylinder is exclusive; reaching cylinder 40 ends the comparison without another disk swap.

## Example: COMP message storage

```asm
msg_open_error           label   byte
                db      0Dh,0Ah
                db      "Open error on file "

open_error_file_digit    label   byte
                db      "x"
```

`mov dx,offset msg_open_error` loads the address of that actual declaration. The file digit is separate because the error handler patches it for operand 1 or 2.

## Byte maps and verification

The detailed maps remain in `mappings/<variant>.tsv`, including original bytes, file offsets, COM/runtime addresses, emitting source file/line and current assembly statement. The map checker now reads assembly statements directly, honoring IBM/Microsoft conditionals and includes, and skips macro definitions. It derives data sizes from DB/DW and retains the already-verified instruction boundaries. Regeneration refreshes source locations after documentation/label edits; changed instruction counts or offsets require remapping instead of silently inventing new boundaries.

```sh
make -B check-utilities
python3 tools/asm_byte_map.py diskcopy diskcomp mode comp ibmfmt msfmt ibmboot msboot
```

The forced build passed: all seven COM outputs and both 512-byte boot outputs match their originals exactly, and all nine MASM runs report zero warnings/errors. LINK retains its usual no-stack-segment warning for these COM-style programs. The map audit passes with the hex comments removed. The quoted-string parser was also checked with embedded commas and semicolons. Runtime disk operations have not been executed.

CHKDSK source is outside this requested readability pass; its existing byte map and byte-exact rebuild check remain intact.

Original binaries now live in `reference/`. The Makefile checks and byte-map checker use that directory; assembler/linker tools continue to run from `bin/`.
