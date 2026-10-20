; *-------------------------------------------------------------------------
; FILCOM.ASM - Microsoft File Compare Utility, 21-Jan-82
;
; Original: reference/filcom.com, 8320 bytes; COM load address 0100h.
; Build: make filcom.com     Verify: make check-utilities
; Code, descriptor tables, FCBs, messages and initialized buffers are separated.
; Binary mode compares bytes; text mode searches for matching line windows.
; /A forces text, /B binary, /C includes comments, /S enables source processing.
; A numeric switch selects the required run of matching lines (default 3).
;
; The original contains translated 8080-style register and flag sequences.
; Preserve LAHF/SAHF, stack exchanges and indirect return continuations exactly.
; Text uses both NUL and high-bit terminators; do not normalize these encodings.
; Exact addresses and bytes are recorded separately in mappings/filcom.tsv.
; Byte identity and representative DOS-emulator comparisons are verified.
; *-------------------------------------------------------------------------

program         segment
                assume  cs:program, ds:program, es:program
                org     100h

; Preserve the original near branch, including branches within short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

terminate_psp equ start - 100h
psp_memory_size                 equ     6
psp_command_length              equ     80h

; Preserve the original 16-bit displacement for the preceding character.
cmp_previous_char macro imm
                db 80h,0BFh,0FFh,0FFh,imm
                endm
set_previous_char macro imm
                db 0C6h,87h,0FFh,0FFh,imm
                endm

; COM entry: pass the application callback to the common command runtime.
start:
                mov      bx,offset cmp_files
                jmpn     init_runtime

; Build display names, select binary/text comparison, then close all files.
cmp_files:
                mov      al,ds:[first_fcb]
                add      al,40h
                mov      byte ptr ds:[first_heading_drive],al
                mov      al,3Ah
                mov      byte ptr ds:[first_heading_colon],al
                mov      bx,offset first_fcb_name
                mov      ch,0Bh
                mov      dx,offset first_heading_name

copy_first_display_name:
                mov      al,[bx]
                inc      bx
                lahf     
                push     ax
                sub      al,60h
                jae      uppercase_first_name
                jmpn     preserve_first_name

uppercase_first_name:
                pop      ax
                sahf     
                sub      al,20h
                jmpn     store_first_name

preserve_first_name:
                pop      ax
                sahf     

store_first_name:
                mov      di,dx
                stosb    
                inc      dx
                dec      ch
                jne      copy_first_display_name
                call     check_binary_extension
                mov      al,ds:[second_fcb]
                add      al,40h
                mov      byte ptr ds:[second_heading_drive],al
                mov      al,3Ah
                mov      byte ptr ds:[second_heading_colon],al
                mov      bx,offset second_fcb_name
                mov      ch,0Bh
                mov      dx,offset second_heading_name

copy_second_display_name:
                mov      al,[bx]
                inc      bx
                lahf     
                push     ax
                sub      al,60h
                jae      uppercase_second_name
                jmpn     preserve_second_name

uppercase_second_name:
                pop      ax
                sahf     
                sub      al,20h
                jmpn     store_second_name

preserve_second_name:
                pop      ax
                sahf     

store_second_name:
                mov      di,dx
                stosb    
                inc      dx
                dec      ch
                jne      copy_second_display_name
                call     check_binary_extension
                mov      al,ds:[force_ascii]
                or       al,al
                jne      force_text_comparison
                jmpn     init_cmp_state

force_text_comparison:
                xor      al,al
                mov      byte ptr ds:[binary_cmp],al

init_cmp_state:
                mov      ch,16h
                mov      bx,offset first_line_poss
                mov      dx,offset first_line_numbers
                sub      al,al
                mov      byte ptr ds:[diffs_seen],al
                mov      al,ds:[binary_cmp]
                rcr      al,1
                jb       run_binary_comparison
                jmpn     clear_first_line_window

run_binary_comparison:
                call     cmp_binary
                jmpn     close_files_and_restart

clear_first_line_window:
                mov      [bx],al
                mov      di,dx
                stosb    
                inc      bx
                inc      dx
                dec      ch
                jne      clear_first_line_window
                mov      ch,16h
                mov      bx,offset second_line_poss
                mov      dx,offset second_line_numbers

clear_second_line_window:
                mov      [bx],al
                mov      di,dx
                stosb    
                inc      bx
                inc      dx
                dec      ch
                jne      clear_second_line_window
                mov      byte ptr ds:[first_input_end],al
                mov      byte ptr ds:[second_input_end],al
                mov      al,ds:[required_matching_lines]
                mov      byte ptr ds:[matching_lines_left],al
                mov      bx,0
                mov      word ptr ds:[first_text_pos],bx
                mov      word ptr ds:[second_text_pos],bx
                mov      word ptr ds:[saved_first_pos],bx
                mov      word ptr ds:[saved_second_pos],bx
                mov      bx,word ptr ds:[initial_stack]
                mov      dx,80h
                sub      bx,dx
                mov      dx,offset text_storage_remainder
                sub      bx,dx
                mov      al,bh
                rcr      al,1
                mov      bh,al
                mov      al,bl
                rcr      al,1
                mov      bl,al
                mov      word ptr ds:[text_buffer_capacity],bx
                mov      dx,offset text_buffer_storage
                add      bx,dx
                mov      al,bl
                mov      byte ptr ds:[second_buffer_base],al
                mov      al,bh
                mov      byte ptr ds:[second_base_high],al
                mov      al,53h
                mov      byte ptr ds:[wrap_pos_patch],al
                mov      bx,offset first_input_desc
                call     read_desc_line
                mov      bx,offset second_input_desc
                call     read_desc_line
                mov      al,ds:[first_input_end]
                or       al,al
                jne      check_second_end
                jmpn     cmp_text_window

check_second_end:
                mov      al,ds:[second_input_end]
                or       al,al
                jne      disable_buffer_wrap
                jmpn     cmp_text_window

disable_buffer_wrap:
                mov      al,0C3h
                mov      byte ptr ds:[wrap_pos_patch],al

cmp_text_window:
                call     resync_lines
                mov      al,ds:[resync_result]
                or       al,al
                jne      handle_resync_diff
                jmpn     handle_first_window

handle_resync_diff:
                dec      al
                jne      handle_unresyncd_text
                jmpn     print_first_heading

handle_unresyncd_text:
                mov      bx,offset files_different_text
                mov      al,ds:[diffs_seen]
                or       al,al
                je       print_files_different
                jmpn     print_first_heading

print_files_different:
                call     print_highbit_string
                jmpn     close_files_and_restart

print_first_heading:
                call     print_diff_separator
                mov      bx,offset first_diff_heading
                call     print_highbit_string

handle_first_window:
                mov      al,ds:[resync_result]
                cmp      al,2
                je       print_remaining_first
                jmpn     advance_first_window

print_remaining_first:
                mov      bx,offset first_output_desc
                call     print_desc_lines
                jmpn     check_second_heading

advance_first_window:
                mov      bx,offset first_search_desc
                call     advance_desc_line

check_second_heading:
                mov      al,ds:[resync_result]
                or       al,al
                jne      print_second_heading
                jmpn     handle_second_window

print_second_heading:
                mov      bx,offset second_diff_heading
                call     print_highbit_string

handle_second_window:
                mov      al,ds:[resync_result]
                cmp      al,2
                je       print_remaining_second
                jmpn     advance_second_window

print_remaining_second:
                mov      bx,offset second_output_desc
                call     print_desc_lines
                jmpn     close_files_and_restart

advance_second_window:
                mov      bx,offset second_search_desc
                call     advance_desc_line
                sub      al,al
                inc      al
                mov      byte ptr ds:[diffs_seen],al
                mov      bx,word ptr ds:[second_line_poss]
                mov      word ptr ds:[second_text_pos],bx
                mov      word ptr ds:[saved_second_pos],bx
                mov      bx,word ptr ds:[first_line_poss]
                mov      word ptr ds:[first_text_pos],bx
                mov      word ptr ds:[saved_first_pos],bx
                mov      al,ds:[resync_result]
                cmp      al,2
                jne      check_first_remaining
                jmpn     close_files_and_restart

check_first_remaining:
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                jne      check_second_remaining
                jmpn     check_second_tail

check_second_remaining:
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                je       print_first_tail
                jmpn     cmp_text_window

print_first_tail:
                call     print_diff_separator
                mov      bx,offset first_diff_heading
                call     print_highbit_string
                mov      bx,offset first_output_desc
                call     print_desc_lines
                jmpn     close_files_and_restart

check_second_tail:
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                jne      print_second_tail
                jmpn     close_files_and_restart

print_second_tail:
                call     print_diff_separator
                mov      bx,offset second_diff_heading
                call     print_highbit_string
                mov      bx,offset second_output_desc
                call     print_desc_lines

close_files_and_restart:
                call     finish_output
                call     close_first
                call     close_second
                jmpn     start

; Separate additional difference groups with a row of dashes.
print_diff_separator:
                mov      al,ds:[separator_printed]
                or       al,al
                jne      emit_separator
                jmpn     mark_first_separator

emit_separator:
                push     cx
                lahf     
                push     ax
                mov      al,0Ah
                call     output_char
                mov      ch,18h

separator_dash_loop:
                mov      al,2Dh
                call     output_char
                dec      ch
                jne      separator_dash_loop
                pop      ax
                sahf     
                pop      cx
                ret      

mark_first_separator:
                inc      al
                mov      byte ptr ds:[separator_printed],al
                ret      

print_lf:
                mov      al,0Ah
                call     output_char
                ret      

files_different_text                    label   byte
                db       0Ah,0Dh,"Files are "
                db       "differen",0F4h

default_source_extension                label   byte
                db       "ASM",0h

default_backup_extension                label   byte
                db       "BAK",0h

separator_printed                       label   byte
                db       0h

; Input descriptor words: byte callback, end-position pointer, buffer-base
; pointer, and EOF-flag pointer. The callback returns through a saved continuation.
first_input_desc                        label   word
                dw       offset read_first_byte
                dw       offset first_buffer_end
                dw       offset first_buffer_base
                dw       offset first_input_end

second_input_desc                       label   word
                dw       offset read_second_byte
                dw       offset second_buffer_end
                dw       offset second_buffer_base
                dw       offset second_input_end

; Search descriptor words: line numbers, line positions, buffer base,
; current position, end position, EOF flag, and byte callback.
first_search_desc                       label   word
                dw       offset first_line_numbers
                dw       offset first_line_poss
                dw       offset first_buffer_base
                dw       offset first_text_pos
                dw       offset first_buffer_end
                dw       offset first_input_end
                dw       offset read_first_byte

second_search_desc                      label   word
                dw       offset second_line_numbers
                dw       offset second_line_poss
                dw       offset second_buffer_base
                dw       offset second_text_pos
                dw       offset second_buffer_end
                dw       offset second_input_end
                dw       offset read_second_byte

line_window_descs                       label   word
                dw       offset first_line_poss
                dw       offset first_line_numbers

second_line_window                      label   word
                dw       offset second_line_poss
                dw       offset second_line_numbers

; Output descriptor words: buffer base, current/end positions, EOF flag,
; byte callback, and line-number window.
first_output_desc                       label   word
                dw       offset first_buffer_base
                dw       offset first_text_pos
                dw       offset first_buffer_end
                dw       offset first_input_end
                dw       offset read_first_byte
                dw       offset first_line_numbers

second_output_desc                      label   word
                dw       offset second_buffer_base
                dw       offset second_text_pos
                dw       offset second_buffer_end
                dw       offset second_input_end
                dw       offset read_second_byte
                dw       offset second_line_numbers

; Compare raw bytes. Report unequal bytes and which file continues past EOF.
cmp_binary:
                mov      bx,offset first_heading_name
                mov      dx,offset binary_first_name
                mov      cl,2

cmp_binary_load:
                mov      ch,0Bh

cmp_binary_load_2:
                mov      al,[bx]
                inc      bx
                mov      di,dx
                stosb    
                inc      dx
                dec      ch
                jne      cmp_binary_load_2
                mov      bx,offset second_heading_name
                mov      dx,offset binary_second_name
                dec      cl
                jne      cmp_binary_load
                mov      dx,0
                mov      bx,offset binary_diff_heading
                call     print_highbit_string

cmp_binary_next:
                call     read_first_byte
                mov      ch,al
                mov      bx,offset first_file_size
                mov      dx,offset binary_offset
                call     cmp_dwords
                jne      cmp_binary_next_2
                jmpn     binary_next_byte

cmp_binary_next_2:
                call     read_second_byte
                mov      cl,al
                mov      bx,offset second_file_size
                mov      dx,offset binary_offset
                call     cmp_dwords
                jne      cmp_binary_load_3
                jmpn     binary_next_byte_load_4

cmp_binary_load_3:
                mov      al,cl
                cmp      al,ch
                je       cmp_binary_load_4
                call     print_binary_diff

cmp_binary_load_4:
                mov      bx,offset binary_offset
                call     increment_dword
                jmp      short cmp_binary_next

larger_text                             label   byte
                db       "LARGER",0Dh,8Ah

binary_offset                           label   word
                dw       0h
                db       0h,0h

binary_next_byte:
                mov      bx,offset second_file_size
                mov      dx,offset binary_offset
                call     cmp_dwords
                jne      binary_next_byte_load
                ret      

binary_next_byte_load:
                mov      bx,offset binary_offset
                call     print_address
                mov      ch,19h

binary_next_byte_load_2:
                mov      al,20h
                call     output_char
                dec      ch
                jne      binary_next_byte_load_2

binary_next_byte_load_3:
                mov      bx,offset larger_text
                call     print_highbit_string
                ret      

binary_next_byte_load_4:
                mov      bx,offset binary_offset
                call     print_address
                mov      ch,7

binary_next_byte_load_5:
                mov      al,20h
                call     output_char
                dec      ch
                jne      binary_next_byte_load_5
                jmp      short binary_next_byte_load_3

; BX points to a little-endian address; print the low three bytes in hex.
print_address:
                lahf     
                inc      bx
                sahf     
                lahf     
                inc      bx
                sahf     
                mov      al,[bx]
                call     print_hex_byte
                lahf     
                dec      bx
                sahf     
                mov      al,[bx]
                call     print_hex_byte
                lahf     
                dec      bx
                sahf     
                mov      al,[bx]
                call     print_hex_byte

print_address_return:
                ret      

; Increment the four-byte little-endian integer addressed by BX.
increment_dword:
                inc      byte ptr [bx]
                jne      print_address_return
                lahf     
                inc      bx
                sahf     
                inc      byte ptr [bx]
                jne      print_address_return
                lahf     
                inc      bx
                sahf     
                inc      byte ptr [bx]
                jne      print_address_return
                lahf     
                inc      bx
                sahf     
                inc      byte ptr [bx]

increment_dword_return:
                ret      

; Compare four bytes at BX and DX; return ZF from the first unequal byte.
cmp_dwords:
                mov      al,[bx]
                xchg     bx,dx
                cmp      al,[bx]
                jne      increment_dword_return
                lahf     
                inc      bx
                sahf     
                lahf     
                inc      dx
                sahf     
                mov      al,[bx]
                xchg     bx,dx
                cmp      al,[bx]
                jne      increment_dword_return
                lahf     
                inc      bx
                sahf     
                lahf     
                inc      dx
                sahf     
                mov      al,[bx]
                xchg     bx,dx
                cmp      al,[bx]
                jne      increment_dword_return
                lahf     
                inc      bx
                sahf     
                lahf     
                inc      dx
                sahf     
                mov      al,[bx]
                xchg     bx,dx
                cmp      al,[bx]
                ret      

; Print the current offset and both differing byte values.
print_binary_diff:
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                push     cx
                mov      bx,offset binary_offset
                call     print_address
                mov      ch,9

print_binary_diff_load:
                mov      al,20h
                call     output_char
                dec      ch
                jne      print_binary_diff_load
                xor      al,al
                inc      al
                mov      byte ptr ds:[print_octal],al
                pop      ax
                xchg     al,ah
                sahf     
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                pop      ax
                xchg     al,ah
                sahf     
                call     print_hex_byte
                mov      ch,10h

print_binary_diff_load_2:
                mov      al,20h
                call     output_char
                dec      ch
                jne      print_binary_diff_load_2
                pop      ax
                xchg     al,ah
                sahf     
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                pop      ax
                xchg     al,ah
                sahf     
                call     print_hex_byte
                mov      al,0Ah
                call     output_char
                mov      al,0Dh
                call     output_char
                ret      

; Choose binary comparison for COM, EXE or OBJ unless /A overrides it.
check_binary_extension:
                mov      bx,offset binary_extensions
                mov      cl,3
                dec      dx
                dec      dx
                dec      dx

check_binary_extension_save:
                push     dx
                mov      ch,3

check_binary_extension_load:
                mov      si,dx
                lodsb    
                cmp      al,[bx]
                je       check_binary_extension_advance
                jmpn     check_binary_extension_advance_2

check_binary_extension_advance:
                inc      bx
                inc      dx
                dec      ch
                jne      check_binary_extension_load
                mov      al,1
                mov      byte ptr ds:[binary_cmp],al
                pop      dx
                ret      

check_binary_extension_advance_2:
                inc      bx
                dec      ch
                jne      check_binary_extension_advance_2
                pop      dx
                dec      cl
                jne      check_binary_extension_save
                ret      

; BX points to text whose final byte has bit 7 set. Clear it before output.
print_highbit_string:
                mov      al,[bx]
                rol      al,1
                jae      print_highbit_string_ror
                jmpn     print_highbit_string_ror_2

print_highbit_string_ror:
                ror      al,1
                call     output_char
                inc      bx
                jmp      short print_highbit_string

print_highbit_string_ror_2:
                ror      al,1
                and      al,7Fh
                call     output_char
                ret      

binary_extensions                       label   byte
                db       "COMEXEOBJ"

copyright_banner                        label   byte
                db       " "

banner_text                             label   byte
                db       "Microsoft File Compare Utility  [21-Jan-"
                db       "82]",0Dh,0Ah,"Copyright (C) 1981 by Microsoft, In"
                db       "c.",0Dh,0Ah,0Dh,0Ah,0h

banner_return:
                ret      

; Compare the current text lines, then search ahead when they differ.
; Paired position/count windows retain candidates without rereading the files.
; A candidate must match required_matching_lines consecutive lines before the
; caller can report the skipped text and resume at a common position.
resync_lines:
                sub      al,al
                mov      byte ptr ds:[resync_result],al
                mov      byte ptr ds:[first_search_exhausted],al
                mov      byte ptr ds:[search_limit_reached],al

reset_resync_count:
                sub      al,al
                mov      byte ptr ds:[resync_work],al

restart_text_search:
                sub      al,al
                mov      byte ptr ds:[second_search_exhausted],al
                call     init_text_cmp
                mov      bx,word ptr ds:[text_buffer_capacity]
                mov      cx,bx
                mov      al,ds:[line_match_state]
                cmp      al,1
                jne      check_text_end_flags
                jmpn     check_matching_line_ends

check_text_end_flags:
                mov      al,ds:[first_text_end]
                mov      bx,offset second_text_end
                or       al,[bx]
                je       check_first_empty_line
                jmpn     restart_matching_run

check_first_empty_line:
                mov      al,ds:[first_char]
                or       al,al
                jne      check_first_comment_line
                jmpn     check_other_line_content

check_first_comment_line:
                cmp      al,3Bh
                jne      check_second_empty_line
                jmpn     check_other_line_content

check_second_empty_line:
                mov      al,ds:[second_char]
                or       al,al
                jne      check_second_comment_line
                jmpn     check_second_search_done

check_second_comment_line:
                cmp      al,3Bh
                jne      begin_difference_search
                jmpn     check_second_search_done

begin_difference_search:
                jmpn     restart_matching_run

check_other_line_content:
                mov      al,ds:[second_char]
                or       al,al
                jne      check_other_line_comment
                jmpn     shift_first_matching_window

check_other_line_comment:
                cmp      al,3Bh
                jne      mark_second_search_done
                jmpn     shift_first_matching_window

mark_second_search_done:
                sub      al,al
                inc      al
                mov      byte ptr ds:[second_search_exhausted],al
                jmpn     shift_first_matching_window

restart_matching_run:
                mov      al,ds:[required_matching_lines]
                mov      byte ptr ds:[matching_lines_left],al
                mov      al,1
                mov      byte ptr ds:[resync_result],al
                mov      al,ds:[search_limit_reached]
                or       al,al
                je       check_search_input_ends
                jmpn     select_search_direction

check_search_input_ends:
                mov      al,ds:[first_text_end]
                mov      bx,offset second_text_end
                or       al,[bx]
                je       try_candidate_line_pairs
                jmpn     select_search_direction

try_candidate_line_pairs:
                sub      al,al
                mov      byte ptr ds:[resync_work],al
                call     search_matching_lines
                mov      al,ds:[line_match_state]
                sbb      al,1
                jne      mark_search_limit
                jmpn     check_matching_line_ends

mark_search_limit:
                sub      al,al
                inc      al
                mov      byte ptr ds:[search_limit_reached],al

select_search_direction:
                mov      al,ds:[first_search_exhausted]
                or       al,al
                je       check_second_search_end
                jmpn     try_first_search_direction

check_second_search_end:
                mov      al,ds:[second_text_end]
                or       al,al
                je       shift_second_search_window
                jmpn     reset_second_search_origin

shift_second_search_window:
                mov      bx,offset second_line_window
                call     shift_line_window
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[second_line_poss],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                je       reset_second_search_origin
                jmpn     reset_resync_count

reset_second_search_origin:
                sub      al,al
                inc      al
                mov      byte ptr ds:[first_search_exhausted],al
                mov      bx,word ptr ds:[saved_second_pos]
                mov      word ptr ds:[second_line_poss],bx
                mov      bx,word ptr ds:[first_buffer_end]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_poss]
                sub      bx,dx
                jne      check_first_search_end
                jmpn     return_search_failure

check_first_search_end:
                mov      al,ds:[first_text_end]
                or       al,al
                je       advance_first_search_origin
                jmpn     return_search_failure

advance_first_search_origin:
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[first_line_poss],bx
                mov      word ptr ds:[saved_first_pos],bx
                jmpn     reset_resync_count

try_first_search_direction:
                mov      al,ds:[first_text_end]
                or       al,al
                je       advance_first_candidate
                jmpn     retry_first_search

advance_first_candidate:
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[first_line_poss],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                je       retry_first_search
                jmpn     reset_resync_count

retry_first_search:
                sub      al,al
                mov      byte ptr ds:[first_search_exhausted],al
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                jne      check_second_candidate_end
                jmpn     return_search_failure

check_second_candidate_end:
                mov      al,ds:[second_text_end]
                or       al,al
                je       advance_second_search_origin
                jmpn     return_search_failure

advance_second_search_origin:
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[second_line_poss],bx
                mov      word ptr ds:[saved_second_pos],bx
                mov      bx,word ptr ds:[saved_first_pos]
                mov      word ptr ds:[first_line_poss],bx
                jmpn     reset_resync_count

return_search_failure:
                mov      al,2
                mov      byte ptr ds:[resync_result],al
                mov      bx,0
                mov      word ptr ds:[first_line_numbers],bx
                mov      word ptr ds:[second_line_numbers],bx
                ret      

check_matching_line_ends:
                mov      bx,offset first_text_end
                mov      al,ds:[second_text_end]
                or       al,[bx]
                je       check_matching_comment_state
                jmpn     restart_matching_run

check_matching_comment_state:
                mov      al,ds:[noncomment_text_seen]
                or       al,al
                je       check_matching_first_char
                jmpn     count_matching_line

check_matching_first_char:
                mov      al,ds:[first_char]
                or       al,al
                jne      test_matching_comment_start
                jmpn     shift_first_matching_window

test_matching_comment_start:
                cmp      al,3Bh
                jne      count_matching_line
                jmpn     shift_first_matching_window

count_matching_line:
                mov      bx,offset resync_work
                inc      byte ptr [bx]
                mov      al,ds:[matching_lines_left]
                cmp      al,[bx]
                jne      shift_first_matching_window
                jmpn     finish_matching_run

shift_first_matching_window:
                mov      bx,offset line_window_descs
                call     shift_line_window
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[first_line_poss],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                je       advance_second_matching_line
                jmpn     check_second_search_done

advance_second_matching_line:
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                je       save_second_matching_pos
                jmpn     retry_first_search

save_second_matching_pos:
                xchg     bx,dx
                mov      word ptr ds:[second_line_poss],bx
                ret      

check_second_search_done:
                mov      al,ds:[second_search_exhausted]
                or       al,al
                je       shift_second_matching_window
                jmpn     restart_text_search

shift_second_matching_window:
                mov      bx,offset second_line_window
                call     shift_line_window
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[second_line_poss],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                je       restart_second_search
                jmpn     restart_text_search

restart_second_search:
                jmpn     reset_second_search_origin

mark_resync_failure:
                mov      al,2
                mov      byte ptr ds:[resync_result],al
                mov      bx,0
                mov      word ptr ds:[first_line_numbers],bx
                mov      word ptr ds:[second_line_numbers],bx
                ret      

finish_matching_run:
                sub      al,al
                mov      byte ptr ds:[search_limit_reached],al
                mov      al,ds:[resync_result]
                cmp      al,1
                jne      require_one_more_match
                jmpn     adjust_matched_line_numbers

require_one_more_match:
                mov      al,1
                mov      byte ptr ds:[matching_lines_left],al
                ret      

adjust_matched_line_numbers:
                mov      al,ds:[matching_lines_left]
                dec      al
                mov      bl,al
                mov      bh,0
                add      bx,bx
                mov      cx,bx
                mov      bx,offset first_line_poss
                add      bx,cx
                mov      bx,[bx]
                mov      word ptr ds:[first_line_poss],bx
                mov      bx,offset first_line_numbers
                add      bx,cx
                mov      bx,[bx]
                mov      word ptr ds:[first_line_numbers],bx
                mov      bx,offset second_line_poss
                add      bx,cx
                mov      bx,[bx]
                mov      word ptr ds:[second_line_poss],bx
                mov      bx,offset second_line_numbers
                add      bx,cx
                mov      bx,[bx]
                mov      word ptr ds:[second_line_numbers],bx
                mov      al,1
                mov      byte ptr ds:[matching_lines_left],al
                ret      

first_search_exhausted                  label   byte
                db       0h

second_search_exhausted                 label   byte
                db       0h

; Try candidate pairs from both line windows, extending the look-ahead search.
; Save each trial position so a failed candidate can be undone. On a match,
; retain the selected positions; on exhaustion, let the caller refill/advance.
search_matching_lines:
                call     save_search_poss
                mov      al,5
                lahf     
                push     ax
                mov      al,0Bh
                lahf     
                push     ax
                mov      byte ptr ds:[search_lines_left],al

next_search_depth:
                pop      ax
                sahf     
                dec      al
                lahf     
                push     ax
                je       test_first_search_done
                jmpn     choose_candidate_source

test_first_search_done:
                mov      al,ds:[first_search_exhausted]
                or       al,al
                je       mark_first_candidate_search
                jmpn     unwind_candidate_search

mark_first_candidate_search:
                inc      al
                mov      byte ptr ds:[first_search_exhausted],al
                pop      ax
                sahf     
                mov      al,ds:[search_lines_left]
                lahf     
                push     ax
                mov      bx,word ptr ds:[saved_second_pos]
                mov      word ptr ds:[second_line_poss],bx
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[saved_first_pos],bx
                mov      word ptr ds:[first_line_poss],bx
                jmpn     test_first_candidate_limit

choose_candidate_source:
                mov      al,ds:[first_search_exhausted]
                or       al,al
                je       calculate_second_candidate
                jmpn     calculate_first_candidate

calculate_second_candidate:
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[second_line_poss],bx

test_second_candidate_limit:
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                je       mark_second_candidate_end
                jmpn     compare_candidate_text

mark_second_candidate_end:
                mov      al,1
                mov      byte ptr ds:[second_text_end],al

restore_candidate_counters:
                pop      ax
                sahf     
                pop      ax
                xchg     al,ah
                sahf     
                jmpn     restore_candidate_done_flag

calculate_first_candidate:
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[first_line_poss],bx

test_first_candidate_limit:
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                je       restore_first_candidate_flags
                jmpn     compare_candidate_text

restore_first_candidate_flags:
                pop      ax
                xchg     al,ah
                sahf     
                pop      ax
                xchg     al,ah
                sahf     
                mov      al,1
                mov      byte ptr ds:[first_text_end],al
                jmpn     restore_candidate_done_flag

compare_candidate_text:
                call     init_text_cmp
                mov      al,ds:[noncomment_text_seen]
                or       al,al
                je       check_candidate_comment_mode
                jmpn     test_candidate_line_match

check_candidate_comment_mode:
                mov      al,ds:[compare_comments]
                or       al,al
                jne      test_candidate_line_match
                jmpn     reset_candidate_match_count

test_candidate_line_match:
                mov      al,ds:[line_match_state]
                cmp      al,1
                jne      reset_candidate_match_count
                jmpn     count_candidate_matches

reset_candidate_match_count:
                sub      al,al
                mov      byte ptr ds:[resync_work],al
                mov      al,ds:[first_text_end]
                mov      bx,offset second_text_end
                or       al,[bx]
                jne      candidate_search_unwind
                jmpn     next_search_depth

candidate_search_unwind:
                jmpn     unwind_candidate_search

count_candidate_matches:
                mov      bx,offset resync_work
                inc      byte ptr [bx]
                mov      al,ds:[matching_lines_left]
                cmp      al,[bx]
                jne      shift_second_candidate_window
                jmpn     decrement_search_lines_left

shift_second_candidate_window:
                mov      bx,offset second_line_window
                call     shift_line_window
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[second_line_poss],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                je       mark_second_candidate_eof
                jmpn     shift_first_candidate_window

mark_second_candidate_eof:
                mov      byte ptr ds:[line_match_state],al
                mov      al,1
                mov      byte ptr ds:[second_text_end],al
                jmpn     restore_candidate_counters

shift_first_candidate_window:
                mov      bx,offset line_window_descs
                call     shift_line_window
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[first_line_poss],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                je       mark_first_candidate_eof
                jmpn     compare_candidate_text

mark_first_candidate_eof:
                mov      byte ptr ds:[line_match_state],al
                mov      al,1
                mov      byte ptr ds:[first_text_end],al
                jmpn     restore_candidate_counters

decrement_search_lines_left:
                dec      byte ptr [bx]
                pop      ax
                xchg     al,ah
                sahf     
                pop      ax
                xchg     al,ah
                sahf     
                pop      ax
                xchg     al,ah
                sahf     
                mov      byte ptr ds:[first_search_exhausted],al
                pop      bx
                pop      bx
                pop      bx
                pop      bx
                pop      bx
                pop      bx
                ret      

unwind_candidate_search:
                pop      ax
                xchg     al,ah
                sahf     
                pop      ax
                sahf     
                dec      al
                jne      save_candidate_search_flags
                jmpn     restore_candidate_done_flag

save_candidate_search_flags:
                lahf     
                push     ax
                sub      al,al
                mov      byte ptr ds:[first_search_exhausted],al
                mov      bx,word ptr ds:[saved_first_pos]
                mov      word ptr ds:[first_line_poss],bx
                mov      al,ds:[search_lines_left]
                dec      al
                mov      byte ptr ds:[search_lines_left],al
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                mov      word ptr ds:[saved_second_pos],bx
                mov      word ptr ds:[second_line_poss],bx
                jmpn     test_second_candidate_limit

restore_candidate_done_flag:
                pop      ax
                sahf     
                mov      byte ptr ds:[first_search_exhausted],al
                or       al,al
                je       restore_first_candidate
                jmpn     return_search_status

restore_first_candidate:
                call     rest_first_pos
                ret      

search_lines_left                       label   byte
                db       0h

return_search_status:
                call     rest_second_pos
                ret      

; Save line-window positions on the stack beneath the caller return address.
; The restore routines deliberately discard some slots and restore others: this
; preserves the selected search position on one side while unwinding the trial.
save_search_poss:
                pop      dx
                mov      bx,word ptr ds:[first_line_numbers]
                push     bx
                mov      bx,word ptr ds:[second_line_numbers]
                push     bx
                mov      bx,word ptr ds:[saved_first_pos]
                push     bx
                mov      bx,word ptr ds:[first_line_poss]
                push     bx
                mov      bx,word ptr ds:[saved_second_pos]
                push     bx
                mov      bx,word ptr ds:[second_line_poss]
                push     bx
                mov      word ptr ds:[saved_second_pos],bx
                mov      al,ds:[first_search_exhausted]
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                sub      al,al
                mov      byte ptr ds:[first_search_exhausted],al
                push     dx
                ret      

; Unwind a search while retaining the selected primary position.
rest_first_pos:
                pop      dx
                pop      bx
                pop      bx
                mov      word ptr ds:[saved_second_pos],bx
                pop      bx
                mov      word ptr ds:[first_line_poss],bx
                pop      bx
                mov      word ptr ds:[saved_first_pos],bx
                pop      bx
                pop      bx
                mov      word ptr ds:[first_line_numbers],bx
                push     dx
                ret      

; Unwind a search while retaining the selected secondary position.
rest_second_pos:
                pop      dx
                pop      bx
                mov      word ptr ds:[second_line_poss],bx
                pop      bx
                mov      word ptr ds:[saved_second_pos],bx
                pop      bx
                pop      bx
                mov      word ptr ds:[saved_first_pos],bx
                pop      bx
                mov      word ptr ds:[second_line_numbers],bx
                pop      bx
                push     dx
                ret      

search_limit_reached                    label   byte
                db       0h

; Convert BX to five decimal digits using successive decimal divisors.
print_decimal:
                push     dx
                mov      dx,offset decimal_divisors
                mov      al,5

next_decimal_place:
                push     cx
                lahf     
                push     ax
                push     bx
                xchg     bx,dx
                mov      cl,[bx]
                inc      bx
                mov      ch,[bx]
                push     cx
                inc      bx
                pop      si
                xchg     bx,si
                push     si
                xchg     bx,dx
                mov      bx,word ptr ds:[decimal_remainder]
                mov      ch,2Fh

subtract_decimal_divisor:
                inc      ch
                sub      bx,dx
                jae      subtract_decimal_divisor
                add      bx,dx
                mov      word ptr ds:[decimal_remainder],bx
                pop      dx
                pop      bx
                mov      [bx],ch
                inc      bx
                pop      ax
                sahf     
                pop      cx
                dec      al
                jne      next_decimal_place
                mov      [bx],al
                pop      dx
                ret      

decimal_divisors                        label   word
                dw       2710h
                dw       3E8h
                dw       64h
                dw       0Ah
                dw       1h

decimal_remainder                       label   word
                dw       0h

decimal_work                            label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h

; BX selects an input descriptor. Invoke its byte callback and fill a circular line buffer.
read_desc_line:
                mov      cx,bx
                mov      bx,[bx]
                xchg     bx,dx
                mov      bx,4
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                push     cx
                push     bx
                push     cx
                push     dx
                mov      cx,bx
                mov      bx,word ptr ds:[text_buffer_capacity]
                xchg     bx,dx

invoke_input_callback:
                mov      bx,offset desc_input_return
                pop      si
                xchg     bx,si
                push     si
                jmp      bx

; Indirect input callback returns here; continue line assembly and EOF bookkeeping.
desc_input_return:
                jae      store_descriptor_character
                jmpn     mark_descriptor_input_end

store_descriptor_character:
                push     bx
                cmp      al,0Ah
                je       invoke_input_callback
                mov      di,cx
                stosb    
                inc      cx
                dec      dx
                or       dx,dx
                jne      invoke_input_callback
                pop      dx
                pop      dx
                pop      dx
                mov      bx,word ptr ds:[text_buffer_capacity]
                dec      bx
                jmpn     save_descriptor_input_end

mark_descriptor_input_end:
                mov      bx,6
                pop      dx
                add      bx,dx
                mov      bx,[bx]
                mov      al,1
                mov      [bx],al
                pop      dx
                mov      bx,cx
                sub      bx,dx

save_descriptor_input_end:
                xchg     bx,dx
                mov      bx,2
                pop      cx
                add      bx,cx
                mov      bx,[bx]
                mov      [bx],dx
                inc      bx
                ret      

; Advance a descriptor-backed line, preserving the surrounding search state.
advance_desc_line:
                push     cx
                push     dx
                push     bx
                mov      cx,bx
                mov      bx,2
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                xchg     bx,dx
                mov      bx,8
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                sub      bx,dx
                je       use_descriptor_end_position
                jmpn     use_descriptor_window_start

use_descriptor_end_position:
                xchg     bx,dx
                mov      word ptr ds:[saved_line_end],bx
                jmpn     reset_descriptor_line_count

use_descriptor_window_start:
                mov      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                xchg     bx,dx
                mov      bx,2
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                push     cx
                push     bx
                mov      bx,word ptr ds:[text_buffer_capacity]
                mov      cx,bx
                pop      bx
                call     wrap_buffer_pos
                xchg     bx,dx
                pop      cx
                mov      bx,2
                add      bx,cx
                mov      bx,[bx]
                mov      word ptr ds:[saved_line_end],dx
                mov      [bx],dx
                inc      bx

reset_descriptor_line_count:
                mov      bx,cx
                mov      bx,[bx]
                sub      al,al
                mov      [bx],al
                inc      bx
                mov      [bx],al
                mov      bx,6
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                mov      word ptr ds:[resync_work],bx

test_descriptor_line_end:
                mov      bx,word ptr ds:[saved_line_end]
                xchg     bx,dx
                mov      bx,word ptr ds:[resync_work]
                sub      bx,dx
                je       restore_descriptor_registers
                jmpn     check_descriptor_output_mode

restore_descriptor_registers:
                pop      bx
                pop      dx
                pop      cx
                ret      

check_descriptor_output_mode:
                mov      al,ds:[resync_result]
                cmp      al,1
                je       load_descriptor_buffer_byte
                jmpn     test_descriptor_eof_flag

load_descriptor_buffer_byte:
                mov      bx,4
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                xchg     bx,dx
                mov      bx,word ptr ds:[resync_work]
                add      bx,dx
                mov      al,[bx]
                lahf     
                push     ax
                call     output_char
                pop      ax
                sahf     
                cmp      al,0Dh
                je       print_descriptor_newline
                jmpn     test_descriptor_eof_flag

print_descriptor_newline:
                mov      al,0Ah
                call     output_char

test_descriptor_eof_flag:
                mov      bx,0Ah
                add      bx,cx
                mov      bx,[bx]
                mov      al,[bx]
                cmp      al,1
                jne      load_descriptor_input_callback
                jmpn     advance_descriptor_position

load_descriptor_input_callback:
                mov      bx,0Ch
                add      bx,cx
                mov      bx,[bx]
                push     bx
                mov      bx,offset descriptor_callback_return
                pop      si
                xchg     bx,si
                push     si
                jmp      bx

descriptor_callback_return:
                jb       update_descriptor_end_position
                jmpn     test_descriptor_line_feed

update_descriptor_end_position:
                mov      bx,word ptr ds:[resync_work]
                xchg     bx,dx
                mov      bx,8
                add      bx,cx
                mov      bx,[bx]
                mov      [bx],dx
                inc      bx
                mov      bx,0Ah
                add      bx,cx
                mov      bx,[bx]
                mov      al,1
                mov      [bx],al

advance_descriptor_position:
                mov      bx,word ptr ds:[resync_work]
                mov      dx,1
                push     cx
                push     bx
                mov      bx,word ptr ds:[text_buffer_capacity]
                mov      cx,bx
                pop      bx
                call     wrap_buffer_pos
                pop      cx
                mov      word ptr ds:[resync_work],bx
                jmpn     test_descriptor_line_end

test_descriptor_line_feed:
                cmp      al,0Ah
                je       test_descriptor_eof_flag
                lahf     
                push     ax
                mov      bx,4
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                xchg     bx,dx
                mov      bx,word ptr ds:[resync_work]
                add      bx,dx
                pop      ax
                sahf     
                mov      [bx],al
                mov      bx,word ptr ds:[resync_work]
                xchg     bx,dx
                mov      bx,8
                add      bx,cx
                mov      bx,[bx]
                mov      [bx],dx
                inc      bx
                xchg     bx,dx
                mov      dx,1
                push     cx
                push     bx
                mov      bx,word ptr ds:[text_buffer_capacity]
                mov      cx,bx
                pop      bx
                call     wrap_buffer_pos
                pop      cx
                mov      word ptr ds:[resync_work],bx
                jmpn     test_descriptor_line_end

; Print the lines selected by an output descriptor, wrapping within the text buffer.
print_desc_lines:
                mov      cx,bx
                push     bx
                mov      bx,[bx]
                mov      bx,[bx]
                push     bx
                mov      bx,4
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                mov      word ptr ds:[first_buffer_end],bx
                mov      bx,2
                add      bx,cx
                mov      bx,[bx]
                mov      bx,[bx]
                mov      word ptr ds:[first_text_pos],bx
                mov      bx,word ptr ds:[text_buffer_capacity]
                mov      cx,bx

print_buffered_line_character:
                mov      bx,word ptr ds:[first_text_pos]
                pop      dx
                push     dx
                add      bx,dx
                mov      al,[bx]
                lahf     
                push     ax
                call     output_char
                pop      ax
                sahf     
                cmp      al,0Dh
                je       print_buffered_newline
                jmpn     advance_buffered_output_pos

print_buffered_newline:
                mov      al,0Ah
                call     output_char

advance_buffered_output_pos:
                mov      bx,word ptr ds:[first_text_pos]
                mov      dx,1
                call     wrap_buffer_pos
                mov      word ptr ds:[first_text_pos],bx
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                jne      print_buffered_line_character
                pop      dx
                pop      cx
                mov      bx,6
                add      bx,cx
                mov      bx,[bx]
                mov      al,[bx]
                cmp      al,1
                jne      load_output_input_callback

return_descriptor_output:
                ret      

load_output_input_callback:
                mov      bx,8
                add      bx,cx
                mov      bx,[bx]

invoke_output_input_callback:
                mov      dx,offset output_input_callback_return
                push     dx
                jmp      bx

output_input_callback_return:
                jb       return_descriptor_output
                lahf     
                push     ax
                call     output_char
                pop      ax
                sahf     
                cmp      al,0Dh
                jne      invoke_output_input_callback
                mov      al,0Ah
                call     output_char
                jmp      short invoke_output_input_callback

; Obtain the next primary text character and apply source normalization.
next_first_char:
                call     first_pos_remaining
                je       mark_first_text_end
                jmpn     load_first_buffer_character

mark_first_text_end:
                mov      dx,offset first_text_end
                mov      al,1
                mov      di,dx
                stosb    
                jmpn     mark_first_line_pending

load_first_buffer_character:
                mov      bx,offset text_buffer_storage
                add      bx,dx
                mov      al,[bx]
                rol      al,1
                jae      test_first_space
                jmpn     skip_first_source_character

test_first_space:
                ror      al,1
                cmp      al,20h
                jne      test_first_tab
                jmpn     test_first_source_whitespace

test_first_tab:
                cmp      al,9
                jne      test_first_carriage_return
                jmpn     test_first_source_whitespace

test_first_carriage_return:
                cmp      al,0Dh
                je       advance_first_line_end
                jmpn     save_first_normalized_char

advance_first_line_end:
                call     first_pos_remaining
                mov      bx,offset first_line_numbers
                jne      increment_first_line_count
                jmpn     mark_first_line_pending

increment_first_line_count:
                inc      byte ptr [bx]
                je       carry_first_line_count
                jmpn     mark_first_line_pending

carry_first_line_count:
                inc      bx
                inc      byte ptr [bx]
                jmpn     mark_first_line_pending

test_first_source_whitespace:
                mov      al,ds:[source_cmp]
                or       al,al
                jne      skip_first_source_character
                jmpn     save_first_normalized_char

skip_first_source_character:
                call     first_pos_remaining
                mov      bx,offset first_line_numbers
                mov      dx,offset first_text_end
                je       set_first_source_end
                jmpn     advance_first_source_line

set_first_source_end:
                mov      al,1
                mov      di,dx
                stosb    
                jmpn     mark_first_line_pending

advance_first_source_line:
                inc      byte ptr [bx]
                jne      next_first_char
                inc      bx
                inc      byte ptr [bx]
                jmp      short next_first_char

mark_first_line_pending:
                mov      bx,offset first_line_pending
                mov      al,1
                mov      [bx],al
                jmpn     return_first_character

save_first_normalized_char:
                mov      byte ptr ds:[first_char],al

return_first_character:
                ret      

; Obtain the next secondary text character and apply source normalization.
next_second_char:
                call     second_pos_remaining
                je       mark_second_text_end
                jmpn     load_second_buffer_character

mark_second_text_end:
                mov      dx,offset second_text_end
                mov      al,1
                mov      di,dx
                stosb    
                jmpn     mark_second_line_pending

load_second_buffer_character:
                mov      bx,word ptr ds:[second_buffer_base]
                add      bx,dx
                mov      al,[bx]
                rol      al,1
                jae      test_second_space
                jmpn     skip_second_source_character

test_second_space:
                ror      al,1
                cmp      al,20h
                jne      test_second_tab
                jmpn     test_second_source_whitespace

test_second_tab:
                cmp      al,9
                jne      test_second_carriage_return
                jmpn     test_second_source_whitespace

test_second_carriage_return:
                cmp      al,0Dh
                je       advance_second_line_end
                jmpn     save_second_normalized_char

advance_second_line_end:
                call     second_pos_remaining
                mov      bx,offset second_line_numbers
                jne      increment_second_line_count
                jmpn     mark_second_line_pending

increment_second_line_count:
                inc      byte ptr [bx]
                je       carry_second_line_count
                jmpn     mark_second_line_pending

carry_second_line_count:
                inc      bx
                inc      byte ptr [bx]
                jmpn     mark_second_line_pending

test_second_source_whitespace:
                mov      al,ds:[source_cmp]
                or       al,al
                jne      skip_second_source_character
                jmpn     save_second_normalized_char

skip_second_source_character:
                call     second_pos_remaining
                mov      bx,offset second_line_numbers
                mov      dx,offset second_text_end
                je       set_second_source_end
                jmpn     advance_second_source_line

set_second_source_end:
                mov      al,1
                mov      di,dx
                stosb    
                jmpn     mark_second_line_pending

advance_second_source_line:
                inc      byte ptr [bx]
                jne      next_second_char
                inc      bx
                inc      byte ptr [bx]
                jmp      short next_second_char

mark_second_line_pending:
                mov      bx,offset second_line_pending
                mov      al,1
                mov      [bx],al
                jmpn     return_second_character

save_second_normalized_char:
                mov      byte ptr ds:[second_char],al

return_second_character:
                ret      

; Parse a filename token into the common FCB work area.
parse_fname:
                call     reset_fname_parser

parse_fname_next:
                call     scan_fname_token
                call     dispatch_fname
                jae      parse_fname_next
                call     finish_fname
                mov      al,cl

parse_fname_return:
                ret      

; Uppercase an ASCII lowercase letter; other characters pass through.
uppercase_char:
                cmp      al,61h
                jb       parse_fname_return
                cmp      al,7Bh
                jae      parse_fname_return
                sub      al,20h
                ret      

dispatch_command:
                push     bx
                mov      bx,offset command_dispatch_table
                jmp      short dispatch_char

dispatch_fname:
                push     bx
                mov      bx,offset fname_dispatch_table

; Dispatch CL through a count-prefixed table of character/handler entries.
dispatch_char:
                push     cx
                pushf    
                mov      ch,[bx]
                inc      bx

dispatch_char_load:
                mov      al,[bx]
                inc      bx
                cmp      al,cl
                jne      dispatch_char_advance
                popf     
                pop      cx
                mov      bx,[bx]
                mov      al,cl
                pop      si
                xchg     bx,si
                push     si
                ret      

dispatch_char_advance:
                inc      bx
                inc      bx
                dec      ch
                jne      dispatch_char_load
                popf     
                pop      cx
                pop      bx
                mov      al,cl
                stc      
                ret      

dispatch_switch:
                push     bx
                mov      bx,offset switch_dispatch_table
                jmp      short dispatch_char

; Scan a name token; CH counts accepted characters and CL receives its delimiter.
scan_fname_token:
                mov      ch,0
                push     bx

scan_fname_token_next:
                call     skip_command_space
                cmp      al,5Bh
                jae      scan_fname_token_test
                cmp      al,30h
                jb       scan_fname_token_test
                cmp      al,41h
                jae      scan_fname_token_advance
                cmp      al,3Ah
                jae      scan_fname_token_test

scan_fname_token_advance:
                inc      ch
                jmp      short scan_fname_token_next

scan_fname_token_test:
                cmp      al,61h
                jb       scan_fname_token_save
                cmp      al,7Bh
                jb       scan_fname_token_advance

scan_fname_token_save:
                push     bx
                mov      bx,offset fname_punctuation
                mov      cl,[bx]
                inc      bx

scan_fname_token_test_2:
                cmp      al,[bx]
                lahf     
                inc      bx
                sahf     
                je       scan_fname_token_rest
                dec      cl
                jne      scan_fname_token_test_2
                pop      bx
                mov      cl,al
                pop      dx

scan_fname_token_return:
                ret      

scan_fname_token_rest:
                pop      bx
                jmp      short scan_fname_token_advance

; Skip spaces, tabs and LF. Control-C prints a notice and terminates via the PSP.
skip_command_space:
                mov      al,[bx]
                and      al,7Fh
                inc      bx
                cmp      al,0Ah
                je       skip_command_space
                cmp      al,20h
                je       skip_command_space
                cmp      al,9
                je       skip_command_space
                cmp      al,3
                jne      scan_fname_token_return
                mov      bx,offset control_c_text
                call     print_zero_string
                jmpn     terminate_psp

control_c_text                          label   byte
                db       "^C",0Dh,0Ah,0h

copy_extension:
                mov      al,[bx]
                or       al,al
                jns      scan_fname_token_return
                inc      bx
                mov      dx,[bx]
                inc      bx
                inc      bx
                add      bx,dx

copy_extension_load:
                mov      si,cx
                lodsb    
                mov      [bx],al
                or       al,al
                je       scan_fname_token_return
                inc      bx
                inc      cx
                jmp      short copy_extension_load

copy_parsed_fcb:
                mov      al,ds:[parsed_fcb_length]
                mov      cl,al
                mov      dx,offset parsed_fname_present

copy_parsed_fcb_load:
                mov      si,dx
                lodsb    
                mov      [bx],al
                inc      dx
                inc      bx
                dec      cl
                jne      copy_parsed_fcb_load
                ret      

; Count followed by character/handler pairs. Each handler address is a word.
command_dispatch_table                  label   byte
                db       5h,"/"
                dw       offset parse_switch
                db       ";"
                dw       offset parse_semicolon
                db       ","
                dw       offset parse_comma
                db       0Dh
                dw       offset parse_command_end
                db       "="
                dw       offset parse_equals

; Switch handlers share the same dispatch convention as command delimiters.
switch_dispatch_table                   label   byte
                db       4h,"A"
                dw       offset set_ascii_switch
                db       "B"
                dw       offset set_binary_switch
                db       "C"
                dw       offset set_comments_switch
                db       "S"
                dw       offset set_source_switch

switch_number                           label   byte
                db       0h

switch_value                            label   byte
                db       0h

fname_index                             label   byte
                db       0h

equals_seen                             label   byte
                db       0h

application_entry                       label   word
                dw       0h

initial_stack                           label   word
                dw       0h

command_active                          label   byte
                db       0h

batch_command                           label   byte
                db       0h

source1_prompt                          label   byte
                db       "Source1"

source2_prompt                          label   byte
                db       "Source2"

list_prompt                             label   byte
                db       "List   "

fname_prompt                            label   byte
                db       "        filename ["

prompt_drive                            label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h

prompt_suffix                           label   byte
                db       "]: ",0h

prompt_name_table                       label   word
                dw       offset source1_prompt
                dw       offset source2_prompt
                dw       offset list_prompt

fcb_pointer_table                       label   word
                dw       12E8h
                dw       1310h
                dw       12C0h

default_extension_table                 label   word
                dw       offset default_source_extension
                dw       offset default_backup_extension
                dw       offset default_output_extension

not_found_text                          label   byte
                db       "File not found",0h

cannot_create_text                      label   byte
                db       "Can't create file",0h

disk_full_text                          label   byte
                db       "Disk "

disk_full_drive                         label   byte
                db       "  full",0h

command_error_text                      label   byte
                db       "Command error: '"

bad_command_char                        label   byte
                db       " '",0h

bad_fname_text                          label   byte
                db       "Bad filename",0h

bad_switch_text                         label   byte
                db       "Bad switch: /"

bad_switch_char                         label   byte
                db       " ",0h

; Save application entry, initialize stack/runtime, and obtain the first command.
init_runtime:
                mov      word ptr ds:[application_entry],bx
                mov      al,ds:[psp_command_length]
                mov      byte ptr ds:[batch_command],al

prompt_command:
                mov      al,ds:[second_device_state]
                or       al,al
                jne      prompt_command_load
                call     banner_return
                jmpn     terminate_psp

prompt_command_load:
                mov      di,offset switch_number
                mov      cx,4
                xor      al,al
                rep      stosb
                mov      byte ptr ds:[first_fcb_name],20h
                mov      bx,offset parse_command
                jmpn     init_stack

; Read a command; normalize a trailing comma before parsing.
read_command:
                call     read_command_line
                push     bx
                dec      bx

read_command_advance:
                inc      bx
                cmp      byte ptr [bx],0Dh
                jne      read_command_advance
                cmp_previous_char 2Ch
                jne      read_command_rest
                set_previous_char 0Dh
                mov      byte ptr [bx],0Ah

read_command_rest:
                pop      bx
                ret      

; Parse file operands and switches; prompt for omitted operands.
parse_command:
                cmp      byte ptr ds:[command_active],0
                jne      begin_command_parse
                inc      byte ptr ds:[command_active]
                mov      bx,offset banner_text
                call     print_zero_string

begin_command_parse:
                call     prompt_fname
                call     read_command

begin_command_parse_next:
                call     parse_fname
                jb       bad_fname

begin_command_parse_next_2:
                call     dispatch_command
                jae      begin_command_parse_next
                mov      byte ptr ds:[bad_command_char],al
                mov      bx,offset command_error_text
                jmp      short bad_fname_next

; Build a source/list prompt with the current default drive and filename.
prompt_fname:
                mov      al,ds:[fname_index]
                shl      al,1
                cbw      
                push     ax
                mov      bx,ax
                mov      si,[bx+prompt_name_table]
                mov      di,offset fname_prompt
                mov      cx,7
                cld      
                rep      movsb
                mov      dx,offset prompt_drive
                call     format_drive_prefix
                mov      di,dx
                mov      bx,offset first_fcb_name
                mov      cx,8
                cmp      byte ptr ds:[fname_index],3
                jne      prompt_fname_load
                mov      bx,offset null_device_name
                mov      cx,3

prompt_fname_load:
                mov      al,[bx]
                cmp      al,20h
                je       prompt_fname_load_2
                call     uppercase_char
                inc      bx
                stosb    
                loop     prompt_fname_load

prompt_fname_load_2:
                mov      al,2Eh
                stosb    
                pop      bx
                mov      si,[bx+default_extension_table]

prompt_fname_lodsb:
                lodsb    
                test     al,al
                je       prompt_fname_load_3
                call     uppercase_char
                stosb    
                jmp      short prompt_fname_lodsb

prompt_fname_load_3:
                mov      si,offset prompt_suffix
                mov      cx,4
                rep      movsb
                mov      bx,offset fname_prompt
                ret      

; Print a NUL-terminated console string, stripping the high bit.
print_zero_string:
                mov      al,[bx]
                and      al,7Fh
                or       al,al
                jne      print_zero_string_next
                ret      

print_zero_string_next:
                call     console_char
                inc      bx
                jmp      short print_zero_string

bad_fname:
                mov      bx,offset bad_fname_text

bad_fname_next:
                call     print_error
                jmpn     begin_command_parse

report_command_error:
                call     print_error
                jmpn     prompt_command

; Prefix an error with ?, print it, and stop a batch command on failure.
print_error:
                mov      al,3Fh
                call     console_char
                call     print_zero_string
                call     print_console_crlf
                cmp      byte ptr ds:[batch_command],0
                je       print_error_return
                jmpn     terminate_psp

print_error_return:
                ret      

print_console_crlf:
                mov      al,0Dh
                call     console_char
                mov      al,0Ah
                jmpn     console_char

source_open_error:
                mov      bx,offset not_found_text
                jmp      short report_command_error

output_create_error:
                mov      bx,offset cannot_create_text
                jmp      short report_command_error

output_write_error:
                mov      byte ptr ds:[disk_full_drive],al
                mov      bx,offset disk_full_text
                call     report_command_error
                jmpn     terminate_psp

; Decode /A, /B, /C, /S, or a numeric resynchronization count.
parse_switch:
                pushf    
                call     skip_command_space
                mov      byte ptr ds:[bad_switch_char],al
                call     uppercase_char
                cmp      al,30h
                jl       parse_switch_load
                cmp      al,39h
                jg       parse_switch_load
                sub      al,30h
                mov      byte ptr ds:[required_matching_lines],al
                jmp      short parse_switch_next

parse_switch_load:
                mov      cl,al
                clc      
                call     dispatch_switch
                jae      parse_switch_next
                mov      bx,offset bad_switch_text
                jmpn     bad_fname_next

parse_switch_next:
                call     skip_command_space
                mov      cl,al
                popf     
                jmpn     begin_command_parse_next_2

set_ascii_switch:
                mov      byte ptr ds:[force_ascii],1
                ret      

set_binary_switch:
                mov      byte ptr ds:[binary_cmp],1
                ret      

set_comments_switch:
                mov      byte ptr ds:[compare_comments],1

set_source_switch:
                mov      byte ptr ds:[source_cmp],1
                ret      

parse_semicolon:
                push     bx
                call     parse_comma

parse_semicolon_test:
                cmp      byte ptr ds:[fname_index],3
                jae      parse_comma_rest
                call     default_output_fname
                call     accept_fname
                call     reset_fname_parser
                jmp      short parse_semicolon_test

parse_command_end:
                call     check_fname_separator
                jne      parse_command_end_next
                call     default_output_fname

parse_command_end_next:
                call     parse_comma
                cmp      byte ptr ds:[fname_index],3
                jae      open_cmp_files
                call     prompt_fname
                call     read_command
                clc      
                ret      

parse_comma:
                push     bx
                call     check_fname_separator
                jne      parse_comma_next
                call     parse_equals

parse_comma_next:
                call     accept_fname

parse_comma_rest:
                pop      bx
                clc      
                ret      

parse_equals:
                mov      byte ptr ds:[equals_seen],1
                ret      

default_output_fname:
                pushf    
                cmp      byte ptr ds:[fname_index],3
                jne      default_output_fname_popf
                call     default_null_output
                pop      ax
                or       ax,ax
                pushf    
                mov      byte ptr ds:[parsed_fname_present],0FFh

default_output_fname_popf:
                popf     
                ret      

check_fname_separator:
                jne      check_fname_separator_return
                cmp      byte ptr ds:[fname_index],0
                jne      check_fname_separator_load
                jmpn     prompt_command

check_fname_separator_load:
                mov      al,ds:[equals_seen]
                test     al,al

check_fname_separator_return:
                ret      

; Open both input files and the selected output before invoking the application.
open_cmp_files:
                call     open_first
                call     open_second
                call     check_output_device
                call     create_output
                mov      bx,word ptr ds:[initial_stack]
                mov      sp,bx
                push     word ptr ds:[application_entry]
                mov      ch,ds:[switch_value]
                inc      ch
                mov      byte ptr ds:[second_device_state],0
                ret      

accept_fname:
                mov      al,ds:[fname_index]
                cmp      al,3
                jae      accept_fname_return
                inc      byte ptr ds:[fname_index]
                shl      al,1
                cbw      
                mov      bx,ax
                push     ax
                mov      al,ds:[equals_seen]
                mov      byte ptr ds:[equals_seen],0
                test     al,al
                je       accept_fname_load
                mov      byte ptr ds:[parsed_fname_present],0

accept_fname_load:
                mov      bx,[bx+fcb_pointer_table]
                push     bx
                call     copy_parsed_fcb
                pop      bx
                push     bx
                call     inherit_fname
                pop      bx
                pop      di
                mov      cx,[di+default_extension_table]
                call     copy_extension

accept_fname_return:
                ret      

; Recognize NUL and CON so output can bypass file creation when appropriate.
check_output_device:
                mov      cx,2020h
                mov      dx,2020h
                or       cx,word ptr ds:[output_fcb_name]
                or       dx,word ptr ds:[output_name_tail]
                cmp      cx,756Eh
                jne      check_output_device_load
                cmp      dx,206Ch
                je       check_output_device_test

check_output_device_load:
                mov      byte ptr ds:[output_is_file],1

check_output_device_test:
                cmp      cx,6F63h
                jne      check_output_device_test_2
                cmp      dx,206Eh
                je       check_output_device_load_2

check_output_device_test_2:
                cmp      cx,7375h
                jne      check_output_device_return
                cmp      dx,7265h
                jne      check_output_device_return

check_output_device_load_2:
                mov      byte ptr ds:[output_device],cl

check_output_device_return:
                ret      

default_output_extension                label   byte
                db       "DIF",0h

fname_punctuation                       label   byte
                db       9h,"!#$%&()+-"

null_device_name                        label   byte
                db       "NUL     "

fname_dispatch_table                    label   byte
                db       2h,":"
                dw       offset parse_drive_colon
                db       "."
                dw       offset copy_name_token

fname_invalid                           label   byte
                db       0h

fname_delimiter                         label   byte
                db       0h

first_is_console                           label   byte
                db       0h

second_device_state                     label   byte
                db       0FFh

output_device                           label   byte
                db       0h

output_is_file                          label   byte
                db       0h

parsed_fcb_length                       label   byte
                db       "("

parsed_fname_present                    label   byte
                db       0h

parsed_fname_length                     label   word
                dw       0h

parsed_fcb                              label   byte
                db       0h

parsed_name                             label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h

parsed_extension                        label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h

output_fcb                              label   byte
                db       0h

output_fcb_name                         label   byte
                db       0h,0h

output_name_tail                        label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h

; DOS FCBs contain drive/name/extension, file size, and record positions.
first_fcb                               label   byte
                db       0h

first_fcb_name                          label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h

first_file_size                         label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

second_fcb                              label   byte
                db       0h

second_fcb_name                         label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h

second_file_size                        label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h

first_eof                               label   byte
                db       0h

first_read_status                       label   byte
                db       0h

first_buffer_pos                        label   word
                db       0h

first_pos_high                          label   byte
                db       0h

; Primary input: four 128-byte DOS records. This initialized storage is retained.
first_file_buffer                       label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h

output_buffer_pos                       label   word
                db       0h

output_pos_high                         label   byte
                db       0h

; Buffered list output: four 128-byte DOS records.
output_file_buffer                      label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h

second_buffer_pos                       label   word
                db       0h

second_pos_high                         label   byte
                db       0h

; Secondary input: four 128-byte DOS records.
second_file_buffer                      label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h

console_input_max                       label   byte
                db       "P"

console_input_length                    label   byte
                db       0h

console_input_text                      label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h

command_prompt_pointer                  label   word
                dw       0h

; Use DOS memory size from the PSP to choose the stack, then invoke the parser callback.
init_stack:
                xchg     bx,dx
                mov      bx,word ptr ds:[6]
                mov      al,bl
                and      al,0FEh
                mov      bl,al
                mov      sp,bx
                mov      word ptr ds:[initial_stack],bx
                xchg     bx,dx
                jmp      bx

; Clear parser flags and initialize an empty FCB with blank name/extension.
reset_fname_parser:
                push     bx
                xor      al,al
                mov      byte ptr ds:[parsed_fname_present],al
                mov      bx,9
                mov      word ptr ds:[parsed_fname_length],bx
                mov      bx,offset parsed_fcb
                call     init_fcb
                xor      al,al
                mov      byte ptr ds:[fname_delimiter],al
                mov      byte ptr ds:[fname_invalid],al
                pop      bx
                ret      

reject_fname:
                mov      al,0FFh
                mov      byte ptr ds:[fname_invalid],al
                or       al,al

reject_fname_return:
                ret      

inherit_fname:
                mov      al,[bx]
                or       al,al
                jne      reject_fname_return
                dec      al
                mov      [bx],al
                inc      bx
                inc      bx
                inc      bx
                mov      dx,offset first_fcb
                mov      ch,0Ch
                mov      al,[bx]
                or       al,al
                jne      copy_fname_field_advance

copy_fname_field:
                mov      si,dx
                lodsb    
                mov      [bx],al

copy_fname_field_advance:
                inc      dx
                inc      bx
                dec      ch
                jne      copy_fname_field

copy_fname_field_return:
                ret      

default_null_output:
                mov      al,0FFh
                mov      byte ptr ds:[parsed_fname_present],al
                mov      ch,8
                mov      dx,offset null_device_name
                mov      bx,offset parsed_name
                jmp      short copy_fname_field

format_drive_prefix:
                mov      al,ds:[first_fcb]
                or       al,al
                je       copy_fname_field_return
                add      al,40h
                mov      di,dx
                stosb    
                inc      dx
                mov      al,3Ah
                mov      di,dx
                stosb    
                inc      dx
                ret      

parse_drive_colon:
                mov      al,cl
                mov      byte ptr ds:[fname_delimiter],al
                mov      al,ds:[parsed_fcb]
                or       al,al
                jne      reject_fname
                mov      al,ch
                dec      al
                jne      copy_name_token_save
                mov      si,dx
                lodsb    
                call     uppercase_char
                cmp      al,41h
                jb       reject_fname
                cmp      al,5Bh
                jae      reject_fname
                sub      al,40h
                mov      byte ptr ds:[parsed_fcb],al
                or       al,al

parse_drive_colon_return:
                ret      

copy_name_token:
                mov      al,cl
                mov      byte ptr ds:[fname_delimiter],al
                mov      al,ch
                or       al,al
                je       parse_drive_colon_return
                cmp      al,9
                jb       copy_name_token_save
                mov      ch,8

copy_name_token_save:
                push     bx
                mov      bx,offset parsed_name
                call     copy_fname_field
                pop      bx
                or       al,al

copy_name_token_return:
                ret      

finish_fname:
                mov      al,ds:[fname_delimiter]
                push     ax
                mov      al,cl
                mov      byte ptr ds:[fname_delimiter],al
                pop      ax
                cmp      al,2Eh
                jne      finish_fname_je
                call     copy_extension_token

finish_fname_je:
                je       finish_fname_save
                call     copy_name_token

finish_fname_save:
                push     bx
                mov      ch,1
                mov      bx,offset parsed_fname_present
                mov      al,ds:[parsed_name]
                cmp      al,20h
                jne      finish_fname_load
                dec      ch
                jmp      short finish_fname_load_2

finish_fname_load:
                mov      al,ds:[parsed_extension]
                cmp      al,20h
                jne      finish_fname_load_2
                mov      ch,0FFh

finish_fname_load_2:
                mov      [bx],ch
                pop      bx
                mov      al,ds:[fname_delimiter]
                mov      cl,al
                mov      al,ds:[fname_invalid]
                or       al,al
                stc      
                jne      copy_name_token_return
                mov      al,ds:[parsed_fcb]
                or       al,al
                jne      copy_name_token_return
                mov      al,ch
                or       al,al
                ret      

copy_extension_token:
                pushf    
                mov      al,ch
                cmp      al,4
                jb       copy_extension_token_save
                mov      ch,3

copy_extension_token_save:
                push     bx
                mov      bx,offset parsed_extension
                call     copy_fname_field
                pop      bx
                popf     
                ret      

; Consume the PSP command tail once; subsequent reads use DOS buffered console input.
read_command_line:
                mov      word ptr ds:[command_prompt_pointer],bx
                push     cx
                push     dx
                mov      bx,80h
                mov      al,[bx]
                mov      byte ptr [bx],0
                or       al,al
                mov      ch,al

read_command_line_je:
                je       read_console_line_load
                inc      bx
                mov      al,[bx]
                cmp      al,20h
                jne      read_command_line_load
                dec      ch
                jmp      short read_command_line_je

read_command_line_load:
                mov      dx,offset console_input_length
                mov      al,ch
                dec      bx
                inc      ch

read_command_line_load_2:
                mov      di,dx
                stosb    
                inc      dx
                inc      bx
                dec      ch
                je       read_console_line_rest
                mov      al,[bx]
                jmp      short read_command_line_load_2

read_console_line:
                push     cx
                push     dx
                jmp      short read_console_line_load_2

read_console_line_load:
                mov      bx,word ptr ds:[command_prompt_pointer]
                call     print_zero_string

read_console_line_load_2:
                mov      dx,offset console_input_max
                mov      ah,0Ah
                int      21h
                mov      al,0Ah
                call     console_char

read_console_line_rest:
                pop      dx
                pop      cx
                mov      al,ds:[console_input_length]
                mov      bx,offset console_input_text
                push     bx
                add      al,bl
                mov      bl,al
                mov      al,0
                adc      al,bh
                mov      bh,al
                mov      byte ptr [bx],0Dh
                inc      bx
                mov      al,0Ah
                mov      [bx],al
                pop      bx
                ret      

; AL is the character. DOS AH=02h output; preserve DX and the saved arithmetic flags.
console_char:
                push     dx
                lahf     
                push     ax
                and      al,7Fh
                mov      dl,al
                mov      ah,2
                int      21h
                pop      ax
                sahf     
                pop      dx
                or       al,al
                ret      

; Create the output file through DOS FCB AH=16h; use a 512-byte output buffer.
create_output:
                lahf     
                push     ax
                push     cx
                push     dx
                push     bx
                mov      al,ds:[output_device]
                cmp      al,75h
                jne      create_output_load
                jmpn     create_output_rest_2

create_output_load:
                mov      dx,offset output_file_buffer
                mov      bx,0
                mov      word ptr ds:[output_buffer_pos],bx
                mov      bx,offset output_fcb
                xchg     bx,dx
                push     dx
                mov      ah,16h
                int      21h
                inc      al
                jne      create_output_rest
                jmpn     output_create_error

create_output_rest:
                pop      bx

create_output_xchg:
                xchg     bx,dx
                mov      ah,0Fh
                int      21h
                inc      al
                jne      create_output_rest_2
                jmpn     source_open_error

create_output_rest_2:
                pop      bx
                pop      dx
                pop      cx
                pop      ax
                sahf     
                ret      

; Open secondary FCB and initialize its input-buffer position.
open_second:
                lahf     
                push     ax
                push     cx
                push     dx
                push     bx
                mov      bx,200h
                mov      word ptr ds:[second_buffer_pos],bx
                mov      bx,offset second_fcb
                jmp      short create_output_xchg

; Open primary FCB unless the source is a console device.
open_first:
                lahf     
                push     ax
                push     cx
                push     dx
                push     bx
                mov      bx,200h
                mov      word ptr ds:[first_buffer_pos],bx
                mov      al,ds:[first_is_console]
                or       al,al
                jne      create_output_rest_2
                mov      bx,offset first_fcb
                jmp      short create_output_xchg

; Initialize BX FCB: drive zero, eleven spaces, then clear its remaining fields.
init_fcb:
                push     bx
                push     dx
                xor      al,al
                mov      [bx],al
                inc      bx
                mov      al,20h
                mov      dh,0Bh
                call     fill_fcb_bytes
                xor      al,al
                mov      dh,19h
                call     fill_fcb_bytes
                pop      bx
                pop      dx
                ret      

fill_fcb_bytes:
                mov      [bx],al
                inc      bx
                dec      dh
                jne      fill_fcb_bytes
                ret      

; Close the secondary FCB using DOS AH=10h.
close_second:
                lahf     
                push     ax
                push     dx
                mov      dx,offset second_fcb
                jmp      short close_first_load

; Close the primary FCB only when it represents a disk file.
close_first:
                lahf     
                push     ax
                mov      al,ds:[first_is_console]
                or       al,al
                jne      close_first_save
                jmpn     close_first_rest_2

close_first_save:
                push     dx
                mov      dx,offset first_fcb

close_first_load:
                mov      ah,10h
                int      21h

close_first_rest:
                pop      dx

close_first_rest_2:
                pop      ax
                sahf     

close_first_return:
                ret      

; Append final output controls, flush any partial buffer, and close the output FCB.
finish_output:
                lahf     
                push     ax
                push     dx
                mov      al,0Dh
                call     output_char
                mov      al,0Ah
                call     output_char
                mov      al,ds:[output_device]
                cmp      al,75h
                je       close_first_rest
                mov      al,0Ch
                call     output_char
                mov      al,1Ah
                call     output_char
                push     bx
                mov      bx,word ptr ds:[output_buffer_pos]
                mov      dx,offset output_file_buffer
                push     cx
                mov      cx,12C3h
                call     flush_partial_output
                pop      cx
                pop      bx
                mov      dx,offset output_fcb
                jmp      short close_first_load

flush_partial_output:
                or       bx,bx
                je       close_first_return
                mov      al,bl
                and      al,7Fh
                je       flush_partial_output_rcl
                add      al,80h

flush_partial_output_rcl:
                rcl      al,1
                rcl      al,1
                and      al,3
                add      bx,bx
                add      al,bh
                mov      bx,cx
                jmp      short flush_output_buffer_save

; Route AL to console or buffered list-file output according to the selected device.
output_char:
                push     bx
                lahf     
                push     ax
                mov      bl,al
                mov      al,ds:[output_device]
                or       al,al
                jne      output_char_load
                jmpn     output_char_save

output_char_load:
                mov      bh,al
                mov      al,bl
                cmp      al,0Ch
                jne      output_char_load_2
                jmpn     output_char_rest_2

output_char_load_2:
                mov      al,bh
                cmp      al,75h
                je       output_char_rest
                jmpn     output_char_save

output_char_rest:
                pop      ax
                sahf     
                pop      bx
                jmpn     console_char

output_char_save:
                push     dx
                mov      bx,word ptr ds:[output_buffer_pos]
                mov      al,bh
                cmp      al,2
                jne      output_char_advance
                call     flush_output_buffer

output_char_advance:
                inc      bx
                mov      word ptr ds:[output_buffer_pos],bx
                mov      dx,offset output_pos_high
                add      bx,dx
                pop      dx
                pop      ax
                sahf     
                lahf     
                push     ax
                mov      [bx],al

output_char_rest_2:
                pop      ax
                sahf     
                pop      bx
                ret      

; Write four 128-byte records using DOS FCB random-block output, AH=28h.
flush_output_buffer:
                mov      dx,offset output_file_buffer
                mov      bx,offset output_fcb
                mov      al,4

flush_output_buffer_save:
                push     cx
                push     bx
                mov      cl,al
                mov      ch,0
                push     cx
                mov      ah,1Ah
                int      21h
                pop      cx
                pop      dx
                push     dx
                mov      ah,28h
                int      21h
                or       al,al
                pop      dx
                pop      cx
                je       flush_output_buffer_load
                jmpn     report_disk_full

flush_output_buffer_load:
                mov      bx,0
                ret      

; Return one secondary byte, refilling the 512-byte buffer as needed.
read_second_byte:
                push     bx
                push     dx
                mov      bx,word ptr ds:[second_buffer_pos]
                mov      al,bh
                cmp      al,2
                jne      read_second_byte_advance
                call     refill_second

read_second_byte_advance:
                inc      bx
                mov      word ptr ds:[second_buffer_pos],bx
                mov      dx,offset second_pos_high
                add      bx,dx
                pop      dx
                jmpn     read_first_byte_load_4

; Read four sequential FCB records; pad the unfilled tail with DOS EOF markers.
refill_second:
                mov      dx,offset second_file_buffer
                mov      al,4

refill_second_save:
                push     ax
                push     dx
                push     cx
                mov      ah,1Ah
                int      21h
                mov      dx,offset second_fcb
                mov      ah,14h
                int      21h
                pop      cx
                pop      dx
                dec      al
                je       refill_second_xor
                mov      bx,80h
                add      bx,dx
                xchg     bx,dx
                pop      ax
                dec      al
                jne      refill_second_save

refill_second_load:
                mov      bx,0

refill_second_return:
                ret      

refill_second_xor:
                xor      al,al
                inc      al
                mov      byte ptr ds:[first_read_status],al
                pop      ax
                mov      al,1Ah
                mov      di,dx
                stosb    
                jmp      short refill_second_load

; Return one primary byte from a disk buffer or a prompted console line.
read_first_byte:
                push     bx
                push     dx
                mov      bx,word ptr ds:[first_buffer_pos]
                mov      al,ds:[first_is_console]
                or       al,al
                jne      read_first_byte_load
                jmpn     read_first_byte_load_3

read_first_byte_load:
                mov      al,bh
                or       al,al
                jne      read_first_byte_next
                jmpn     read_first_byte_advance

read_first_byte_next:
                call     read_console_line
                mov      bx,0

read_first_byte_advance:
                inc      bx
                mov      word ptr ds:[first_buffer_pos],bx
                mov      dx,offset console_input_length
                add      bx,dx
                pop      dx
                mov      al,[bx]
                cmp      al,0Ah
                je       read_first_byte_load_2
                jmpn     read_first_byte_resume

read_first_byte_load_2:
                mov      byte ptr ds:[first_pos_high],al

read_first_byte_resume:
                jmp      short read_first_byte_load_4

read_first_byte_load_3:
                mov      al,bh
                cmp      al,2
                jne      read_first_byte_advance_2
                call     refill_first

read_first_byte_advance_2:
                inc      bx
                mov      word ptr ds:[first_buffer_pos],bx
                mov      dx,offset first_pos_high
                add      bx,dx
                pop      dx

read_first_byte_load_4:
                mov      al,[bx]
                pop      bx
                cmp      al,1Ah
                stc      
                je       refill_second_return
                or       al,al
                ret      

; Read primary data with DOS random-block FCB input, AH=27h.
refill_first:
                mov      dx,offset first_file_buffer
                mov      bx,offset first_fcb
                mov      al,4
                push     cx
                push     dx
                push     bx
                mov      cl,al
                mov      ch,0
                push     cx
                mov      ah,1Ah
                int      21h
                pop      cx
                pop      dx
                mov      ah,27h
                int      21h
                pop      bx
                dec      al
                jne      refill_first_load
                call     mark_first_eof

refill_first_load:
                mov      bx,0
                pop      cx
                ret      

; Mark primary EOF and terminate the partial buffer with Ctrl-Z.
mark_first_eof:
                xor      al,al
                inc      al
                mov      byte ptr ds:[first_eof],al
                mov      dx,80h

mark_first_eof_count:
                dec      cl
                jns      mark_first_eof_add
                jmpn     mark_first_eof_load

mark_first_eof_add:
                add      bx,dx
                jmp      short mark_first_eof_count

mark_first_eof_load:
                mov      byte ptr [bx],1Ah
                ret      

report_disk_full:
                mov      si,dx
                lodsb    
                add      al,40h
                cmp      al,40h
                je       report_disk_full_load
                jmpn     report_disk_full_resume

report_disk_full_load:
                mov      al,20h

report_disk_full_resume:
                jmpn     output_write_error

; Compare normalized characters from the two current buffered lines.
; Reset per-line flags, skip source whitespace, and handle semicolon comments
; according to compare_comments. line_match_state starts at 1 and is cleared
; on a difference; consume the rest of both lines before returning.
; Buffer allocation happens earlier in cmp_files, not in this routine.
init_text_cmp:
                mov      bx,0
                mov      word ptr ds:[first_line_numbers],bx
                mov      word ptr ds:[second_line_numbers],bx
                sub      al,al
                mov      byte ptr ds:[first_line_pending],al
                mov      byte ptr ds:[second_line_pending],al
                mov      byte ptr ds:[first_text_end],al
                mov      byte ptr ds:[second_text_end],al
                mov      byte ptr ds:[first_char],al
                mov      byte ptr ds:[noncomment_text_seen],al
                mov      byte ptr ds:[comment_prefix_checked],al
                inc      al
                mov      byte ptr ds:[line_match_state],al

init_text_cmp_next:
                call     next_first_char
                call     next_second_char
                mov      al,ds:[comment_prefix_checked]
                or       al,al
                je       init_text_cmp_advance
                jmpn     init_text_cmp_load_3

init_text_cmp_advance:
                inc      al
                mov      byte ptr ds:[comment_prefix_checked],al
                mov      al,ds:[compare_comments]
                or       al,al
                je       init_text_cmp_load
                jmpn     init_text_cmp_load_3

init_text_cmp_load:
                mov      al,ds:[first_char]
                cmp      al,3Bh
                jne      init_text_cmp_load_2
                call     save_cmp_chars

init_text_cmp_load_2:
                mov      al,ds:[second_char]
                cmp      al,3Bh
                jne      init_text_cmp_load_3
                call     save_cmp_chars

init_text_cmp_load_3:
                mov      al,ds:[first_line_pending]
                cmp      al,1
                je       init_text_cmp_load_4
                jmpn     init_text_cmp_load_7

init_text_cmp_load_4:
                mov      al,ds:[second_line_pending]
                cmp      al,1
                jne      init_text_cmp_load_5
                ret      

init_text_cmp_load_5:
                mov      al,ds:[compare_comments]
                or       al,al
                je       init_text_cmp_load_6
                jmpn     init_text_cmp_sub_3

init_text_cmp_load_6:
                mov      al,ds:[second_char]
                cmp      al,3Bh
                je       init_text_cmp_resume
                jmpn     init_text_cmp_sub_3

init_text_cmp_resume:
                jmpn     init_text_cmp_load_19

init_text_cmp_load_7:
                mov      al,ds:[second_line_pending]
                cmp      al,1
                je       init_text_cmp_load_8
                jmpn     init_text_cmp_load_10

init_text_cmp_load_8:
                mov      al,ds:[compare_comments]
                or       al,al
                je       init_text_cmp_load_9
                jmpn     init_text_cmp_sub_3

init_text_cmp_load_9:
                mov      al,ds:[first_char]
                cmp      al,3Bh
                je       init_text_cmp_resume_2
                jmpn     init_text_cmp_sub_3

init_text_cmp_resume_2:
                jmpn     init_text_cmp_load_18

init_text_cmp_load_10:
                mov      al,ds:[first_char]
                mov      bx,offset second_char
                cmp      al,[bx]
                je       init_text_cmp_load_11
                jmpn     init_text_cmp_sub_3

init_text_cmp_load_11:
                mov      bx,offset first_line_numbers
                call     first_pos_remaining
                je       init_text_cmp_sub
                jmpn     init_text_cmp_next_2

init_text_cmp_sub:
                sub      al,al
                inc      al
                mov      byte ptr ds:[first_line_pending],al
                mov      byte ptr ds:[first_text_end],al
                jmpn     init_text_cmp_sub_3

init_text_cmp_next_2:
                call     increment_word
                mov      bx,offset second_line_numbers
                call     second_pos_remaining
                je       init_text_cmp_sub_2
                jmpn     init_text_cmp_next_3

init_text_cmp_sub_2:
                sub      al,al
                inc      al
                mov      byte ptr ds:[second_line_pending],al
                mov      byte ptr ds:[second_text_end],al
                jmpn     init_text_cmp_sub_3

init_text_cmp_next_3:
                call     increment_word
                mov      al,ds:[compare_comments]
                or       al,al
                je       init_text_cmp_load_12
                jmpn     init_text_cmp_next

init_text_cmp_load_12:
                mov      al,ds:[first_char]
                cmp      al,3Bh
                jne      init_text_cmp_load_13
                jmpn     init_text_cmp_load_17

init_text_cmp_load_13:
                mov      al,1
                mov      byte ptr ds:[noncomment_text_seen],al
                jmpn     init_text_cmp_next

init_text_cmp_sub_3:
                sub      al,al
                mov      byte ptr ds:[line_match_state],al
                mov      al,ds:[compare_comments]
                or       al,al
                je       init_text_cmp_load_14
                jmpn     init_text_cmp_load_17

init_text_cmp_load_14:
                mov      al,ds:[first_char]
                cmp      al,3Bh
                jne      init_text_cmp_load_15
                jmpn     init_text_cmp_load_17

init_text_cmp_load_15:
                mov      al,ds:[second_char]
                cmp      al,3Bh
                jne      init_text_cmp_load_16
                jmpn     init_text_cmp_load_17

init_text_cmp_load_16:
                mov      al,1
                mov      byte ptr ds:[noncomment_text_seen],al

init_text_cmp_load_17:
                mov      al,ds:[first_line_pending]
                cmp      al,1
                jne      init_text_cmp_load_18
                jmpn     init_text_cmp_load_19

init_text_cmp_load_18:
                mov      bx,offset first_line_numbers
                call     first_pos_remaining
                je       init_text_cmp_sub_4
                jmpn     init_text_cmp_next_4

init_text_cmp_sub_4:
                sub      al,al
                inc      al
                mov      byte ptr ds:[first_line_pending],al
                mov      byte ptr ds:[first_text_end],al
                jmp      short init_text_cmp_sub_3

init_text_cmp_next_4:
                call     increment_word
                call     next_first_char
                jmp      short init_text_cmp_load_17

init_text_cmp_load_19:
                mov      al,ds:[second_line_pending]
                cmp      al,1
                jne      init_text_cmp_load_20
                ret      

init_text_cmp_load_20:
                mov      bx,offset second_line_numbers
                call     second_pos_remaining
                je       init_text_cmp_sub_5
                jmpn     init_text_cmp_next_5

init_text_cmp_sub_5:
                sub      al,al
                inc      al
                mov      byte ptr ds:[second_line_pending],al
                mov      byte ptr ds:[second_text_end],al
                jmp      short init_text_cmp_sub_3

init_text_cmp_next_5:
                call     increment_word
                call     next_second_char
                jmp      short init_text_cmp_load_19

; Compute primary bytes remaining from the current circular line position.
first_pos_remaining:
                push     bx
                mov      bx,word ptr ds:[first_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[first_line_numbers]
                call     wrap_buffer_pos
                xchg     bx,dx
                mov      bx,word ptr ds:[first_buffer_end]
                sub      bx,dx
                pop      bx
                ret      

; Compute secondary bytes remaining from the current circular line position.
second_pos_remaining:
                push     bx
                mov      bx,word ptr ds:[second_line_poss]
                xchg     bx,dx
                mov      bx,word ptr ds:[second_line_numbers]
                call     wrap_buffer_pos
                xchg     bx,dx
                mov      bx,word ptr ds:[second_buffer_end]
                sub      bx,dx
                pop      bx
                ret      

rest_cmp_chars:
                pop      ax
                xchg     al,ah
                sahf     
                mov      byte ptr ds:[second_char],al
                pop      ax
                xchg     al,ah
                sahf     
                mov      byte ptr ds:[first_char],al
                ret      

; Save both normalized characters and arrange their restoration with a synthetic return.
; Stack order is saved first character/flags, saved second character/flags,
; rest_cmp_chars, then the original caller continuation. The caller therefore
; continues first; its eventual RET restores the saved characters and flags.
save_cmp_chars:
                pop      dx
                mov      al,ds:[first_char]
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                mov      al,ds:[second_char]
                lahf     
                xchg     al,ah
                push     ax
                xchg     al,ah
                mov      bx,offset rest_cmp_chars
                push     bx
                push     dx
                ret      

; Shift both arrays of a position/count window to retain recent candidates.
; Copy backwards so overlapping entries survive; required_matching_lines
; determines the retained span. The descriptor supplies the two array pointers.
shift_line_window:
                push     dx
                push     cx
                push     bx
                inc      bx
                inc      bx
                push     bx
                mov      cl,2

shift_line_window_load:
                mov      al,ds:[required_matching_lines]
                rol      al,1
                mov      ch,al
                inc      al
                mov      bl,al
                mov      bh,0
                xchg     bx,dx
                pop      bx
                mov      bx,[bx]
                add      bx,dx
                mov      dh,bh
                mov      dl,bl
                dec      bx
                dec      bx

shift_line_window_load_2:
                mov      al,[bx]
                mov      di,dx
                stosb    
                dec      dx
                dec      bx
                dec      ch
                jne      shift_line_window_load_2
                dec      cl
                jne      shift_line_window_load
                pop      cx
                pop      dx
                ret      

; Add BX+DX and wrap at capacity. Once both inputs end, its PUSH is patched to RET.
wrap_buffer_pos:
                add      bx,dx

wrap_pos_patch:
                push     bx
                mov      dx,word ptr ds:[text_buffer_capacity]
                sub      bx,dx
                jb       wrap_pos_patch_rest
                jmpn     wrap_pos_patch_rest_2

wrap_pos_patch_rest:
                pop      bx
                ret      

wrap_pos_patch_rest_2:
                pop      dx
                ret      

; Increment a word through byte stores while retaining the original instruction sequence.
increment_word:
                mov      dx,[bx]
                inc      bx
                inc      dx
                mov      [bx],dh
                dec      bx
                mov      [bx],dl
                ret      

; Decrement a word through byte stores while retaining the original instruction sequence.
decrement_word:
                mov      dx,[bx]
                inc      bx
                dec      dx
                mov      [bx],dh
                dec      bx
                mov      [bx],dl
                ret      

first_buffer_base                       label   word
                dw       offset text_buffer_storage

; Print BX in octal or hexadecimal according to print_octal.
print_word:
                mov      al,ds:[print_octal]
                or       al,al
                jne      print_word_xor
                jmpn     print_hex_word

print_word_xor:
                xor      al,al
                add      bx,bx
                adc      al,30h
                call     output_char
                push     cx
                mov      ch,5

print_word_xor_2:
                xor      al,al
                mov      cl,3

print_word_add:
                add      bx,bx
                adc      al,al
                dec      cl
                jne      print_word_add
                add      al,30h
                call     output_char
                dec      ch
                jne      print_word_xor_2
                pop      cx
                ret      

print_hex_word:
                mov      al,bh
                call     print_hex_byte
                mov      al,bl

; Print AL as two hexadecimal digits.
print_hex_byte:
                push     cx
                mov      ch,al
                rcr      al,1
                rcr      al,1
                rcr      al,1
                rcr      al,1
                call     print_hex_nibble
                mov      al,ch
                pop      cx

; Print the low nibble of AL as an uppercase hexadecimal digit.
print_hex_nibble:
                and      al,0Fh
                add      al,30h
                cmp      al,3Ah
                jae      print_hex_nibble_add
                jmpn     print_hex_nibble_resume

print_hex_nibble_add:
                add      al,7

print_hex_nibble_resume:
                jmpn     output_char

; Print BX in octal.
print_octal_word:
                mov      bh,al
                xor      al,al
                add      bx,bx
                adc      al,al
                add      bx,bx
                adc      al,al
                add      al,30h
                call     output_char
                mov      ch,2

print_octal_word_xor:
                xor      al,al
                mov      cl,3

print_octal_word_add:
                add      bx,bx
                adc      al,al
                dec      cl
                jne      print_octal_word_add
                add      al,30h
                call     output_char
                dec      ch
                jne      print_octal_word_xor

number_state                            label   byte
                db       0C3h

print_octal                             label   byte
                db       1h

second_buffer_base                      label   word
                db       0h

second_base_high                        label   byte
                db       0h

; Eleven word slots track buffered line positions for resynchronization.
first_line_poss                         label   word
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h

second_line_poss                        label   word
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h

first_line_numbers                      label   word
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h

second_line_numbers                     label   word
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h
                dw       0h

first_line_pending                      label   byte
                db       0h

second_line_pending                     label   byte
                db       0h

first_text_end                          label   byte
                db       0h

second_text_end                         label   byte
                db       0h

first_char                              label   byte
                db       0h

second_char                             label   byte
                db       0h

first_buffer_end                        label   word
                dw       0h

second_buffer_end                       label   word
                dw       0h

first_input_end                         label   byte
                db       0h

second_input_end                        label   byte
                db       0h

first_text_pos                          label   word
                dw       0h

second_text_pos                         label   word
                dw       0h

saved_first_pos                         label   word
                dw       0h

saved_second_pos                        label   word
                dw       0h

; Numeric switch value: consecutive matching lines required to resynchronize.
required_matching_lines                 label   byte
                db       3h

matching_lines_left                     label   byte
                db       0h

; /S is initially enabled; /C also enables it and includes comments.
source_cmp                              label   byte
                db       0FFh

compare_comments                             label   byte
                db       0h

binary_cmp                              label   byte
                db       0h

force_ascii                             label   byte
                db       0h

line_match_state                        label   byte
                db       1h

; Search result: 0 = matching window, 1 = differences, 2 = search failed.
resync_result                           label   byte
                db       1h

; Shared byte/word scratch used by line-search and descriptor processing.
resync_work                             label   byte
                db       0h,0h

diffs_seen                              label   byte
                db       0h

saved_line_end                          label   word
                dw       0h

noncomment_text_seen                     label   byte
                db       0h

comment_prefix_checked                    label   byte
                db       0h

first_diff_heading                      label   byte
                db       0Dh,0Ah,0Dh,0Ah,"--"

first_heading_drive                     label   byte
                db       "-"

first_heading_colon                     label   byte
                db       "-"

first_heading_name                      label   byte
                db       "-           ",0Dh,8Ah

second_diff_heading                     label   byte
                db       0Dh,0Ah,0Dh,0Ah,"--"

second_heading_drive                    label   byte
                db       "-"

second_heading_colon                    label   byte
                db       "-"

second_heading_name                     label   byte
                db       "-           ",0Dh,8Ah

binary_diff_heading                     label   byte
                db       0Dh,0Ah,0Dh,0Ah,"ADDRESS "
                db       "   "

binary_first_name                       label   byte
                db       "                  "

binary_second_name                      label   byte
                db       "             ",0Dh,8Ah

text_buffer_capacity                    label   word
                dw       89h

; Circular text storage grows beyond this initialized tail into available memory.
text_buffer_storage                     label   byte
                db       0h

text_storage_remainder                  label   byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

program         ends
                end     start
