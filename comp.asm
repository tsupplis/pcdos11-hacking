; *-------------------------------------------------------------------------
; COMP.ASM - PC DOS 1.10 file compare utility
;
; Build: make comp.com     Verify: make check-utilities
; Original: reference/comp.com, 1649 bytes; COM load address 0100h.
; Comments describe intent and register/state contracts.
; Exact addresses and bytes are kept in mappings/ and verified on rebuild.
; Reassembly is exact; runtime testing is a separate verification step.
;
; Layout:
; 0100h-0102h  code
; 01A2h-0538h  code
; All remaining image bytes are initialized data, messages, or tables.
; File buffers begin at 0771h, just beyond the initialized image.
; -------------------------------------------------------------------------

program         segment
                assume  cs:program, ds:program
                org     100h

; Preserve near jumps even when the target is in short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

; Exact 8086 encodings: MASM normalizes 82h byte operations to 80h.
; Names show the operation/operand; each macro preserves the original
; encoding.

cmp82_ah                macro   imm
                db      82h,0FCh,imm
                endm

cmp82_mem               macro   addr, imm
                db      82h,3Eh
                dw      addr
                db      imm
                endm

cmp82_bx                macro   imm
                db      82h,3Fh,imm
                endm

; State bits carried across the buffer and disk-swap loops.
flag_one_drive           equ     1
flag_secondary_ahead     equ     2
flag_mismatch_seen       equ     4
flag_missing_eof         equ     8
flag_hex_digit_printed   equ     128

; PSP fields and fixed data addresses (equates do not emit bytes).

; External memory fields and resident patch locations; image data is labeled
; below.
default_second_fcb       equ     6Ch             ; PSP FCB2 at command entry.
psp_end_segment          equ     2h
dos_last_diskette        equ     4h
primary_fcb              equ     5Ch
primary_name             equ     5Dh
primary_record_size      equ     6Ah
primary_file_size        equ     6Ch
command_length           equ     80h
command_tail             equ     81h
primary_buffer           equ     771h

; ------------------------------------------------------------------------
; Code and initialized data in original file order
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; Jump over the copyright banner into initialization.
; ------------------------------------------------------------------------

start:
                jmpn    init
                db      "The IBM Personal Computer File Compare Utility Version 1.10 "
                db      "(C)Copyright IBM Corp 1981, 1982 Licensed Material - "
                db      "Program Property of IBM Author - David Litton "

; ------------------------------------------------------------------------
; Validate DOS drive status and allocate two file buffers from available
; memory.
; ------------------------------------------------------------------------

init:
                cld
                mov     sp,100h
                or      ah,al
                cmp82_ah 0FFh
                jnz     detect_drive_configuration
                call    invalid_drive
                int     20h

detect_drive_configuration:
                int     11h
                and     al,0C0h
                or      al,al
                jnz     allocate_file_buffers
                or      byte ptr ds:[compare_flags],flag_one_drive

; Use at most 160 records per buffer; reduce both buffers together when
; memory is limited.
allocate_file_buffers:
                mov     si,default_second_fcb
                mov     di,offset secondary_fcb
                mov     cx,0Ch
                rep     movsb
                mov     ax,0A0h
                mov     dx,ds:[psp_end_segment]
                mov     bx,ds
                sub     dx,bx
; Reserve working space before splitting available memory between the two
; buffers.
                sub     dx,80h
                cmp     dx,0A00h
                jnc     save_buffer_capacity
                shr     dx,1
                shr     dx,1
                shr     dx,1
                shr     dx,1
                mov     ax,dx

save_buffer_capacity:
                mov     word ptr ds:[records_per_buffer],ax
                mov     cl,7h
                shl     ax,cl
                mov     si,ax
                add     ax,771h
                mov     word ptr ds:[secondary_buffer],ax

check_primary_name:
                cmp82_mem primary_name, 20h
                jnz     check_secondary_name

; ------------------------------------------------------------------------
; Request the first filename if it was not supplied on the command line.
; ------------------------------------------------------------------------

prompt_primary:
                mov     dx,offset msg_enter_primary
                mov     bx,primary_fcb
                call    read_filename
                cmp     al,0FFh
                jz      prompt_primary
                jmp     short check_primary_name

check_secondary_name:
                cmp82_mem secondary_name, 20h
                jnz     default_file_drives
                cmp82_mem secondary_fcb, 0h
                jnz     copy_primary_filename

; ------------------------------------------------------------------------
; Request the second filename or a drive on which to find the same filename.
; ------------------------------------------------------------------------

prompt_secondary:
                mov     dx,offset msg_enter_secondary
                mov     bx,offset secondary_fcb
                call    read_filename
                cmp     al,0FFh
                jz      prompt_secondary
                cmp82_mem filename_text, 0Dh
                jnz     check_secondary_name
                jmp     short prompt_secondary

; A drive-only second operand means compare the same filename on that drive.
copy_primary_filename:
                mov     si,primary_name
                mov     di,offset secondary_name
                mov     cx,0Bh
                rep     movsb

default_file_drives:
                mov     ah,19h
                int     21h
                inc     al
                cmp82_mem primary_fcb, 0h
                jnz     default_secondary_drive
                mov     ds:[primary_fcb],al

default_secondary_drive:
                cmp82_mem secondary_fcb, 0h
                jnz     reject_same_file
                mov     ds:[secondary_fcb],al

; ------------------------------------------------------------------------
; Compare the two FCB drive/name fields and reject identical specifications.
; ------------------------------------------------------------------------

reject_same_file:
                mov     si,primary_fcb
                mov     di,offset secondary_fcb
                mov     cx,0Ch
; Drive plus 8.3 name are compared, not wildcard expansion results.
                repe    cmpsb
                jnz     check_diskette_prompt
                mov     dx,offset msg_same_file
                jmpn    print_result

; Single-drive configurations may already have the requested disk selected
; by DOS.
check_diskette_prompt:
                test    byte ptr ds:[compare_flags],flag_one_drive
                jz      prompt_insert_diskettes
                mov     dx,50h
                mov     ds,dx
                mov     ah,ds:[dos_last_diskette]
                mov     dx,cs
                mov     ds,dx
                inc     ah
                cmp     ah,ds:[primary_fcb]
                jnz     open_compare_files

prompt_insert_diskettes:
                mov     dx,offset msg_insert_diskettes
                mov     ah,9h
                int     21h
                mov     ah,0Ch
                mov     al,1h
                int     21h

; Use 128-byte FCB records for block reads, but compare the full 32-bit byte
; sizes first.
open_compare_files:
                mov     dx,primary_fcb
                mov     word ptr ds:[primary_record_size],80h
                call    open_file
                mov     word ptr ds:[primary_records_left],bx
                mov     ah,1Ah
                mov     dx,primary_buffer
                int     21h
                mov     dx,primary_fcb
                call    read_primary
                mov     dx,offset secondary_fcb
                mov     word ptr ds:[secondary_record_size],80h
                call    open_file
                mov     si,primary_file_size
                mov     di,offset secondary_file_size
                mov     cx,4h
                repe    cmpsb                           ; Compare both words of the original 32-bit file sizes.
                jz      compare_buffers
                mov     dx,offset msg_size_mismatch
                jmpn    print_result

; Alternate which file is prefetched so disk changes can be grouped across
; successive batches.
advance_file_blocks:
                cmp     word ptr ds:[primary_records_left],0h
                jz      files_exhausted
                test    byte ptr ds:[compare_flags],flag_secondary_ahead
                jz      prefetch_secondary
                and     byte ptr ds:[compare_flags],0FDh
                jmpn    read_next_primary

prefetch_secondary:
                or      byte ptr ds:[compare_flags],flag_secondary_ahead
                call    read_secondary
                jmpn    read_next_primary

; The EOF-marker warning is independent of whether the data bytes matched.
files_exhausted:
                test    byte ptr ds:[compare_flags],flag_missing_eof
                jz      check_compare_result
                call    warn_missing_eof

check_compare_result:
                mov     dx,offset msg_files_match
                test    byte ptr ds:[compare_flags],flag_mismatch_seen
                jnz     finish_with_mismatches
                jmpn    print_result

finish_with_mismatches:
                jmpn    finish_compare

read_next_primary:
                mov     dx,primary_buffer
                mov     ah,1Ah
                int     21h
                mov     dx,primary_fcb
                call    read_primary

; ------------------------------------------------------------------------
; Compare the current buffers with REPE CMPSB and track the 32-bit file
; offset.
; ------------------------------------------------------------------------

; Both pointers refer to the same file offset. CX is the exact byte count,
; including a short final record.
compare_buffers:
                test    byte ptr ds:[compare_flags],flag_secondary_ahead
                jnz     set_compare_pointers
                call    read_secondary

set_compare_pointers:
                mov     cx,word ptr ds:[compare_byte_count]
                mov     si,primary_buffer
                mov     di,word ptr ds:[secondary_buffer]

compare_remaining_bytes:
                jcxz    advance_file_offset
                repe    cmpsb
                jnz     report_mismatch

; Accumulate a 32-bit byte offset so mismatch locations remain correct
; beyond 64 KiB.
advance_file_offset:
                mov     bx,word ptr ds:[file_offset_high]
                mov     ax,word ptr ds:[file_offset_low]
                add     ax,word ptr ds:[compare_byte_count]
                adc     bx,0h
                mov     word ptr ds:[file_offset_high],bx
                mov     word ptr ds:[file_offset_low],ax
                jmpn    advance_file_blocks

; ------------------------------------------------------------------------
; Display both differing bytes and their file offset; stop after ten
; mismatches.
; ------------------------------------------------------------------------

; REPE CMPSB advanced past the unequal bytes; back up once to format their
; values and location.
report_mismatch:
                or      byte ptr ds:[compare_flags],flag_mismatch_seen
; CMPSB has already incremented both pointers past the mismatch.
                dec     si
                dec     di
                mov     al,[si]
                mov     dx,offset primary_hex_last_digit
                call    format_hex_byte
                mov     al,[di]
                mov     dx,offset secondary_hex_last_digit
                call    format_hex_byte
                mov     bx,word ptr ds:[file_offset_high]
                mov     ax,si
                sub     ax,771h
                add     ax,word ptr ds:[file_offset_low]
                adc     bx,0h                           ; Carry extends the mismatch position past 64 KiB.
                mov     word ptr ds:[offset_hex_buffer],bx
                inc     si
                inc     di
                mov     dx,offset offset_hex_last_digit
                call    format_hex_byte
                mov     al,ah
                call    format_hex_byte
                mov     ax,word ptr ds:[offset_hex_buffer]
                call    format_hex_byte
                mov     al,ah
                call    format_hex_byte
                mov     bx,cx
                mov     ah,2h
                mov     cx,1Ah
                mov     word ptr ds:[saved_source],si
                mov     si,offset msg_offset_heading

print_offset_heading:
                lodsb
                mov     dl,al
                int     21h
                loop    print_offset_heading
                mov     si,offset offset_hex_buffer
                mov     cx,8h
                and     byte ptr ds:[compare_flags],7Fh

; Suppress leading zeroes in the eight-digit hexadecimal offset, but print
; one zero for offset zero.
skip_offset_leading_zeroes:
                lodsb
                test    byte ptr ds:[compare_flags],flag_hex_digit_printed
                jnz     print_offset_digit
                cmp     al,30h
                jnz     print_offset_digit
                loop    skip_offset_leading_zeroes
                jcxz    check_zero_offset

print_offset_digit:
                mov     dl,al
                int     21h
                or      byte ptr ds:[compare_flags],flag_hex_digit_printed
                loop    skip_offset_leading_zeroes

check_zero_offset:
                test    byte ptr ds:[compare_flags],flag_hex_digit_printed
                jnz     print_mismatching_values
                mov     dl,30h
                int     21h

print_mismatching_values:
                mov     cx,bx
                mov     si,word ptr ds:[saved_source]
                mov     ah,9h
                mov     dx,offset msg_primary_value
                int     21h
                mov     dx,offset msg_secondary_value
                int     21h
                inc     byte ptr ds:[mismatch_count]
                cmp82_mem mismatch_count, 0Ah           ; Stop after the tenth reported mismatch.
                jz      mismatch_limit_reached
                jmpn    compare_remaining_bytes

mismatch_limit_reached:
                mov     dx,offset msg_mismatch_limit

; ------------------------------------------------------------------------
; Print a result or error message at DS:DX, then finish this comparison.
; ------------------------------------------------------------------------

print_result:
                mov     ah,9h
                int     21h

; ------------------------------------------------------------------------
; Reset flags, counts and offset before offering another comparison.
; ------------------------------------------------------------------------

; Keep only the drive-configuration flag; all file-specific state belongs to
; the completed pair.
finish_compare:
                and     byte ptr ds:[compare_flags],flag_one_drive
                mov     byte ptr ds:[mismatch_count],0h
                mov     word ptr ds:[file_offset_high],0h
                mov     word ptr ds:[file_offset_low],0h
                mov     word ptr ds:[secondary_fcb],2000h

; ------------------------------------------------------------------------
; Accept Y/N to compare another pair of files or exit through INT 20h.
; ------------------------------------------------------------------------

ask_another:
                mov     dx,offset msg_compare_more
                mov     ah,9h
                int     21h
                mov     ax,0C01h
                int     21h
                or      al,20h
                cmp     al,79h
                jz      start_next_comparison
                cmp     al,6Eh
                jnz     ask_another
                int     20h

start_next_comparison:
                jmpn    prompt_primary

; ------------------------------------------------------------------------
; DX=prompt, BX=destination FCB. Read a name and parse it with DOS AX=2901h.
; ------------------------------------------------------------------------

read_filename:
                mov     byte ptr ds:[filename_length],0h
                mov     ah,9h
                int     21h
                mov     dx,offset filename_input
                mov     ah,0Ah
                int     21h
                mov     si,offset filename_text
                mov     di,bx
                mov     ax,2901h
                int     21h
                cmp     al,0FFh
                jz      invalid_drive
                ret

; ------------------------------------------------------------------------
; Display the invalid drive error; return AL=FFh.
; ------------------------------------------------------------------------

invalid_drive:
                mov     dx,offset msg_invalid_drive
                mov     ah,9h
                int     21h
                mov     al,0FFh
                ret

; ------------------------------------------------------------------------
; DX=FCB. Obtain record count, open the file and clear its random-record
; fields.
; ------------------------------------------------------------------------

open_file:
                mov     si,dx
                mov     ch,31h
                cmp     dx,5Ch
                jz      get_file_record_count
                mov     ch,32h

; DOS AH=23h supplies the record count used to reject missing and empty
; inputs before opening.
get_file_record_count:
                mov     ah,23h
                int     21h
                or      al,al
                jnz     file_not_found
                mov     bx,[si+21h]
                or      bx,bx
                jz      file_empty
                mov     ah,0Fh
                int     21h
; Original instruction: always equal, so the following open-error branch
; cannot fire.
                cmp     al,al
                jnz     file_open_error
                mov     word ptr [si+20h],0h
                mov     word ptr [si+22h],0h
                mov     word ptr [si+24h],0h

file_io_ret:
                ret

; Discard the open_file return address: this path finishes the comparison
; rather than returning to its caller.
file_not_found:
; Abandon the caller continuation and finish this comparison.
                pop     dx
                mov     ds:[not_found_file_digit],ch
                mov     dx,offset msg_file_not_found
                jmpn    print_result

; Discard the open_file return address and identify which operand was empty.
file_empty:
                pop     dx
                mov     ds:[empty_file_digit],ch
                mov     dx,offset msg_file_empty
                jmpn    print_result

; The original CMP AL,AL makes this error branch unreachable; preserve that
; behavior byte for byte.
file_open_error:
                pop     dx
                mov     ds:[open_error_file_digit],ch
                mov     dx,offset msg_open_error
                jmpn    print_result

; ------------------------------------------------------------------------
; Read primary records with DOS AH=27h and compute the exact final byte
; count.
; ------------------------------------------------------------------------

read_primary:
                mov     cx,word ptr ds:[records_per_buffer]
                cmp     word ptr ds:[primary_records_left],cx
                jnc     read_primary_records
                mov     cx,word ptr ds:[primary_records_left]

; On the final block, replace padded FCB record length with the actual file
; byte remainder.
read_primary_records:
                mov     ah,27h
                int     21h
                mov     ax,word ptr ds:[primary_records_left]
                sub     ax,cx
                mov     word ptr ds:[primary_records_left],ax
                mov     ax,cx
                mov     cl,7h
                shl     ax,cl
                mov     word ptr ds:[compare_byte_count],ax
                cmp     word ptr ds:[primary_records_left],0h
                jnz     file_io_ret
                sub     ax,80h                          ; Remove the padding of the final 128-byte record.
                mov     bx,ds:[primary_file_size]
; Only the low seven size bits describe the partial final record.
                and     bx,7Fh
                or      bx,bx
                jnz     set_final_compare_length
                mov     bx,80h

; Check the final real byte for Ctrl-Z; lack of the marker is reported after
; comparison.
set_final_compare_length:
                add     bx,ax
                mov     word ptr ds:[compare_byte_count],bx
                add     bx,770h
; COMP expects a trailing Ctrl-Z even though the comparison uses the real
; file size.
                cmp82_bx 1Ah
                jz      file_io_ret
                or      byte ptr ds:[compare_flags],flag_missing_eof
                ret

; ------------------------------------------------------------------------
; Print the missing EOF-marker warning.
; ------------------------------------------------------------------------

warn_missing_eof:
                mov     dx,offset msg_missing_eof
                mov     ah,9h
                int     21h
                ret

; ------------------------------------------------------------------------
; Read a block of the secondary file into its own DTA buffer.
; ------------------------------------------------------------------------

read_secondary:
                mov     dx,word ptr ds:[secondary_buffer]
                mov     ah,1Ah
                int     21h
                mov     dx,offset secondary_fcb
                mov     ah,27h
                mov     cx,word ptr ds:[records_per_buffer]
                int     21h
                ret

; ------------------------------------------------------------------------
; AL=byte, DX=last output position. Store two hexadecimal digits in reverse
; order.
; ------------------------------------------------------------------------

; Both nibbles are written backwards into the message field; DX walks left
; through the output.
format_hex_byte:
                mov     ds:[saved_source],al
                mov     bx,offset hex_digits
                call    format_hex_nibble
                mov     al,ds:[saved_source]
                shr     al,1
                shr     al,1
                shr     al,1
                shr     al,1

; ------------------------------------------------------------------------
; Use the hexadecimal lookup table and store a digit at DS:DX.
; ------------------------------------------------------------------------

format_hex_nibble:
                and     al,0Fh
                xlat
                xchg    dx,bx
                mov     [bx],al
                xchg    dx,bx
                dec     dx
                ret

secondary_fcb            label   byte
                db      0h

secondary_name           label   byte
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h

secondary_record_size    label   word
                dw      0

secondary_file_size      label   byte
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

saved_source             label   byte
                db      0h,0h

; Capacity in 128-byte FCB records, shared by both buffers.
records_per_buffer       label   word
                dw      0

secondary_buffer         label   word
                dw      0

primary_records_left     label   word
                dw      0

; Actual bytes to compare; excludes FCB padding in the last 128-byte record.
compare_byte_count       label   word
                db      0h,2h

; Bits: one drive, /1, mismatch seen, geometry known and two heads.
compare_flags            label   byte
                db      0h

filename_input           label   byte
                db      10h

filename_length          label   byte
                db      0h

filename_text            label   byte
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h

file_offset_high         label   word
                dw      0

file_offset_low          label   word
                dw      0

mismatch_count           label   byte
                db      0h

offset_hex_buffer        label   byte
                db      0h,0h,0h,0h,0h,0h,0h

offset_hex_last_digit    label   byte
                db      0h

msg_mismatch_limit       label   byte
                db      0Dh,0Ah
                db      "10 Mismatches - aborting compare"
                db      7h,0Dh,0Ah
                db      "$"

msg_invalid_drive        label   byte
                db      0Dh,0Ah
                db      "Invalid drive specification"
                db      7h,0Dh,0Ah
                db      "$"

hex_digits               label   byte
                db      "0123456789ABCDEF"

msg_offset_heading       label   byte
                db      0Dh,0Ah
                db      "Compare error at offset "

msg_primary_value        label   byte
                db      0Dh,0Ah
                db      "File 1 =  "

primary_hex_last_digit   label   byte
                db      " "
                db      0Dh,0Ah
                db      "$"

msg_secondary_value      label   byte
                db      "File 2 =  "

secondary_hex_last_digit label   byte
                db      " "
                db      0Dh,0Ah
                db      "$"

msg_missing_eof          label   byte
                db      0Dh,0Ah
                db      "Eof mark not found"
                db      7h,0Dh,0Ah
                db      "$"

msg_files_match          label   byte
                db      0Dh,0Ah
                db      "Files compare ok"
                db      0Dh,0Ah
                db      "$"

msg_file_not_found       label   byte
                db      0Dh,0Ah
                db      "File "

not_found_file_digit     label   byte
                db      "x not found"
                db      7h,0Dh,0Ah
                db      "$"

msg_file_empty           label   byte
                db      0Dh,0Ah
                db      "File "

empty_file_digit         label   byte
                db      "x empty"
                db      7h,0Dh,0Ah
                db      "$"

msg_open_error           label   byte
                db      0Dh,0Ah
                db      "Open error on file "

open_error_file_digit    label   byte
                db      "x"
                db      7h,0Dh,0Ah
                db      "$"

msg_enter_primary        label   byte
                db      0Dh,0Ah
                db      "Enter primary file name"
                db      0Dh,0Ah
                db      "$"

msg_insert_diskettes     label   byte
                db      0Dh,0Ah
                db      "Insert diskette(s) with files to compare"
                db      0Dh,0Ah
                db      "and strike any key when ready"
                db      0Dh,0Ah
                db      "$"

msg_enter_secondary      label   byte
                db      0Dh,0Ah
                db      "Enter 2nd file name or drive id"
                db      0Dh,0Ah
                db      "$"

msg_same_file            label   byte
                db      0Dh,0Ah
                db      "Cannot compare file to itself"
                db      7h,0Dh,0Ah
                db      "$"

msg_size_mismatch        label   byte
                db      0Dh,0Ah
                db      "Files are different sizes"
                db      7h,0Dh,0Ah
                db      "$"

msg_compare_more         label   byte
                db      0Dh,0Ah
                db      "Compare more files (Y/N)?$"

program         ends
                end     start
