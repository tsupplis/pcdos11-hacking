; *-------------------------------------------------------------------------
; DEBUG.ASM - PC DOS 1.10 debugger reconstruction
;
; Original: reference/debug.com, 5999 bytes; COM load address 0100h.
; Build: make debug.com     Verify: make check-utilities
; The three code regions are 0100h..02CAh, 02FFh..0510h, 0515h..107Bh.
; Command dispatch, opcode descriptors, mnemonics, messages and stack/register
; storage are data. State beyond the initialized image is named with equates.
;
; DEBUG maintains its own PSP and a separate target PSP at CS+01AEh.
; Target registers are stored in the stack-pop order used by capture/resume.
; INT 1/3 and temporary CC breakpoints return control to the command loop.
; A..Z dispatch includes unsupported commands; Q dispatches to PSP:0000.
; There is no interactive assembler command in this version.
;
; Exact addresses and encodings live in mappings/debug.tsv. Comments and
; names describe inferred behavior; byte identity is verified separately.
; *-------------------------------------------------------------------------

program segment
                assume cs:program, ds:program, es:program
                org 100h

; Preserve E9 branches even when MASM could choose a short jump.
jmpn macro target
                db 0E9h
                dw target - $ - 2
                endm

; Preserve CS-prefixed string fetches and legacy 82h byte operations.
lodsb_cs macro
                db 2Eh,0ACh
                endm
lodsw_cs macro
                db 2Eh,0ADh
                endm

cmp82_ah macro imm
                db 82h,0FCh
                db imm
                endm

cmp82_mem macro addr, imm
                db 82h,03Eh
                dw addr
                db imm
                endm

cmp82_si macro imm
                db 82h,03Ch
                db imm
                endm

cmp82_cl macro imm
                db 82h,0F9h
                db imm
                endm

cmp82_dh macro imm
                db 82h,0FEh
                db imm
                endm

cmp82_dl macro imm
                db 82h,0FAh
                db imm
                endm

add82_mem macro addr, imm
                db 82h,06h
                dw addr
                db imm
                endm

terminate_psp equ start - 100h
; External PSP fields and uninitialized workspace; no bytes are emitted.
psp_end_seg                     equ 2h
psp_cpm_memory_size             equ 6h
psp_cpm_entry_seg               equ 8h
file_fcb                        equ 5Ch
file_name                       equ 5Dh
file_extension                  equ 65h
file_extension_last             equ 67h
fcb_block                       equ 68h
fcb_record_size                 equ 6Ah
fcb_current_record              equ 7Ch
fcb_random_record_low           equ 7Dh
fcb_random_record_high          equ 7Fh
psp_cmd_length                  equ 80h
psp_cmd_tail                    equ 81h
filename_parse_status           equ 18BFh
unassemble_offset               equ 18C0h
unassemble_seg                  equ 18C2h
unassemble_remaining            equ 18C4h
effective_addr                  equ 18C6h
dump_offset                     equ 18C8h
dump_seg                        equ 18CAh
def_range_count                 equ 18CCh
far_pointer_work                equ 18D4h
insn_byte_count                 equ 18D8h
current_mnemonic                equ 18D9h
op_is_word                      equ 18DBh
modrm_rm                        equ 18DCh
modrm_reg                       equ 18DDh
modrm_mode                      equ 18DEh
def_op_seg                      equ 18DFh
override_seg                    equ 18E0h
op_text                         equ 18E1h
breakpt_count                   equ 18F9h
trace_count                     equ 18FBh
cmd_buffer_before               equ 18FCh
cmd_buffer                      equ 18FDh
breakpt_table                   equ 194Dh
exe_header                      equ 197Fh
exe_last_page_bytes             equ 1981h
exe_page_count                  equ 1983h
exe_relocation_count            equ 1985h
exe_header_paragraphs           equ 1987h
exe_max_extra                   equ 198Bh
exe_initial_ss                  equ 198Dh
exe_initial_sp                  equ 198Fh
exe_initial_ip                  equ 1993h
exe_initial_cs                  equ 1995h
exe_relocation_offset           equ 1997h
hex_buffer_end                  equ 1AD8h
target_psp_offset               equ 1AE0h

second_default_fcb equ 6Ch

ivt_trace_offset equ 4
ivt_trace_segment equ 6
ivt_breakpt_offset equ 0Ch
ivt_breakpt_segment equ 0Eh
ivt_ctrl_break_offset equ 8Ch
ivt_ctrl_break_segment equ 8Eh

; Exact forms normalized by MASM: symmetric TEST operands and CS:82h CMP.
test_bx_ax macro
                db 85h,0C3h
                endm
cmp82_cs_mem macro addr, imm
                db 2Eh,82h,3Eh
                dw addr
                db imm
                endm

; DOS FCB random-block functions and intentionally overlaid workspace.
dos_read_block equ 27h
dos_write_block equ 28h
hex_input_buffer equ insn_byte_count
; HEX input reuses 512 bytes from hex_input_buffer through hex_buffer_end.
; This overlays command/operand text, breakpoints and the EXE-header work area.
; Those uses are mutually exclusive while the HEX file is being read.

; Allocate a separate PSP for the target program and initialize its saved registers.

start:
                mov      sp,offset saved_ax
                mov      byte ptr ds:[filename_parse_status],al
                mov      ax,2522h
                mov      dx,offset program_terminated
                int      21h
                mov      al,23h
                mov      dx,offset control_break
                int      21h
                mov      dx,cs
                add      dx,target_psp_offset / 16
                mov      ah,26h
                int      21h
                mov      ax,dx
                mov      di,offset saved_ds
                cld      
                stosw    
                stosw    
                stosw    
                stosw    
                mov      word ptr ds:[unassemble_seg],ax
                mov      word ptr ds:[dump_seg],ax
                mov      ax,100h
                mov      word ptr ds:[unassemble_offset],ax
                mov      word ptr ds:[dump_offset],ax
                mov      ds,dx
                mov      es,dx
                mov      dx,80h
                mov      ah,1Ah
                int      21h

; Adjust the target CP/M-compatible entry and stack limit to its reduced allocation.
                mov      ax,word ptr ds:[6]
                mov      bx,ax
                cmp      ax,0FFF0h
                push     cs
                pop      ds
                jae      save_target_stack_limit
                mov      ax,word ptr ds:[6]
                inc      ah
                sub      ax,target_psp_offset

save_target_stack_limit:
                mov      word ptr ds:[saved_sp],ax
                dec      ah
                mov      word ptr es:[6],ax
                sub      bx,ax
                mov      cl,4
                shr      bx,cl
                add      word ptr es:[8],bx
                mov      ah,0Fh
                int      10h
                cmp82_ah 28h
                jne      parse_initial_filename
                mov      byte ptr ds:[dump_line_mask],7
                mov      byte ptr ds:[regs_per_row],4
                mov      word ptr ds:[def_dump_count],40h

; Parse the initial filename/tail and optionally load the target before prompting.

parse_initial_filename:
                mov      di,file_fcb
                mov      si,psp_cmd_tail
                mov      ax,2901h
                int      21h
                call     copy_target_cmd_tail
                push     cs
                pop      es
                cmp82_mem file_name, 20h
                je       cmd_loop
                call     load_at_def_addr
                mov      ax,word ptr ds:[saved_cs]
                mov      word ptr ds:[unassemble_seg],ax
                mov      ax,word ptr ds:[saved_ip]
                mov      word ptr ds:[unassemble_offset],ax

; Restore DEBUG segments/stack after commands; uppercase the command and dispatch A..Z.

cmd_loop:
                cld      
                mov      ax,cs
                mov      ds,ax
                mov      es,ax
                mov      ss,ax
                mov      sp,offset saved_ax
                sti      
                mov      al,2Dh
                call     print_char
                call     read_cmd_line
                call     skip_whitespace
                je       cmd_loop
                lodsb    
                sub      al,41h
                jb       reject_command
                cmp      al,19h
                ja       reject_command
                shl      al,1
                cbw      
                xchg     bx,ax
                call     word ptr cs:[bx+cmd_dispatch]
                jmp      short cmd_loop

reject_command:
                jmpn     syntax_error_previous

; INT 22h termination entry: regain DEBUG context and report normal target exit.

program_terminated:
                mov      dx,offset terminated_message
                jmp      short print_dos_error

; INT 23h break entry outside execution: regain DEBUG context and return to the prompt.

control_break:
                mov      dx,offset break_message

print_dos_error:
                mov      ax,cs
                mov      ds,ax
                mov      ss,ax
                mov      sp,offset saved_ax
                mov      ah,9
                int      21h
                jmp      short cmd_loop

; Read DOS buffered input. Uppercase command syntax while preserving quoted strings.

read_cmd_line:
                mov      ah,0Ah
                mov      dx,offset console_input_max
                int      21h
                mov      si,offset console_input_text
                mov      di,cmd_buffer

uppercase_command_syntax:
                lodsb    
                cmp      al,61h
                jb       store_command_character
                cmp      al,7Ah
                ja       store_command_character
                add      al,0E0h

store_command_character:
                stosb    
                cmp      al,0Dh
                je       select_parsed_command
                cmp      al,22h
                je       begin_quoted_command_text
                cmp      al,27h
                jne      uppercase_command_syntax

begin_quoted_command_text:
                mov      ah,al

copy_quoted_command_text:
                lodsb    
                stosb    
                cmp      al,0Dh
                je       select_parsed_command
                cmp      al,ah
                jne      copy_quoted_command_text
                jmp      short uppercase_command_syntax

select_parsed_command:
                mov      si,cmd_buffer

; Print CR/LF through the common console character routine.

print_crlf:
                mov      al,0Dh
                call     print_char
                mov      al,0Ah
                jmpn     print_char

erase_echoed_char:
                mov      si,offset erase_char_text

; CS:SI points to text with bit 7 set on the last character; output masks that bit.

print_highbit_string:
                lodsb_cs 
                call     print_char
                shl      al,1
                jae      print_highbit_string
                ret      

; Skip whitespace and at most one comma; return ZF if the remaining text is empty.

skip_opt_comma:
                call     skip_whitespace
                cmp82_si 2Ch
                jne      test_cmd_end
                inc      si

; Skip spaces/tabs at DS:SI; leave SI on the next character and test for CR.

skip_whitespace:
                push     ax

skip_whitespace_character:
                lodsb    
                cmp      al,20h
                je       skip_whitespace_character
                cmp      al,9
                je       skip_whitespace_character
                dec      si
                pop      ax

test_cmd_end:
                cmp82_si 0Dh
                ret      

; H: parse two words and print their 16-bit sum and difference.

cmd_hex_arithmetic:
                mov      cx,4
                call     parse_hex_number
                mov      di,dx
                mov      cx,4
                call     parse_hex_number
                call     require_cmd_end
                push     dx
                add      dx,di
                call     print_hex_word
                call     print_space
                call     print_space
                pop      dx
                sub      di,dx
                mov      dx,di
                call     print_hex_word
                jmp      short print_crlf

; Print DS:SI as a hexadecimal segment:offset address.

print_ds_si:
                mov      dx,ds
                call     print_hex_word
                mov      al,3Ah
                call     print_char
                mov      dx,si
                jmp      short print_hex_word

; Print ES:DI as a hexadecimal segment:offset address.

print_es_di:
                mov      dx,es
                call     print_hex_word
                mov      al,3Ah
                call     print_char
                mov      dx,di

; Print DX as four hexadecimal digits, preserving its value.

print_hex_word:
                mov      al,dh
                call     print_hex_byte
                mov      al,dl

; Print AL as two hex digits. AH is scratch; the character routine preserves AX.

print_hex_byte:
                mov      ah,al
                push     cx
                mov      cl,4
                shr      al,cl
                pop      cx
                call     print_hex_nibble
                mov      al,ah

; Convert AL low nibble using the original DAA sequence; fall through to output.

print_hex_nibble:
                and      al,0Fh
                add      al,90h
                daa      
                adc      al,40h
                daa      

; DOS AH=02h console output. Mask the text terminator bit; preserve AX and DX.

print_char:
                push     ax
                push     dx
                and      al,7Fh
                xchg     dx,ax
                mov      ah,2
                int      21h
                pop      dx
                pop      ax
                ret      

print_space:
                mov      al,20h
                jmp      short print_char

print_spaces:
                call     print_space
                loop     print_spaces
                ret      

; Command letters A..Z, one near pointer each. Q=0 returns through the PSP.

cmd_dispatch                        label word
                dw       offset syntax_error_previous
                dw       offset syntax_error_previous
                dw       offset cmd_compare
                dw       offset cmd_dump
                dw       offset cmd_enter
                dw       offset cmd_fill
                dw       offset cmd_go
                dw       offset cmd_hex_arithmetic
                dw       offset cmd_input_port
                dw       offset syntax_error_previous
                dw       offset syntax_error_previous
                dw       offset cmd_load
                dw       offset cmd_move
                dw       offset cmd_name
                dw       offset cmd_output_port
                dw       offset syntax_error_previous
                dw       terminate_psp
                dw       offset cmd_regs
                dw       offset cmd_search
                dw       offset cmd_trace
                dw       offset cmd_unassemble
                dw       offset syntax_error_previous
                dw       offset cmd_write
                dw       offset syntax_error_previous
                dw       offset syntax_error_previous
                dw       offset syntax_error_previous

; Parse a range using the saved target DS; default to 80h bytes.

parse_ds_range:
                mov      bp,word ptr ds:[saved_ds]
                mov      word ptr ds:[def_range_count],80h

; Return AX=segment, DX=start, CX=count. Accept an inclusive end or L count.

parse_range:
                call     parse_addr
                push     ax
                push     dx
                call     skip_opt_comma
                mov      al,[si]
                cmp      al,4Ch
                je       parse_explicit_length
                mov      dx,word ptr ds:[def_range_count]
                call     peek_hex_digit
                jb       restore_range_start
                mov      cx,4
                call     parse_hex_number
                mov      cx,dx
                pop      dx
                sub      cx,dx
                inc      cx
                pop      ax
                ret      

parse_explicit_length:
                inc      si
                mov      cx,4
                call     parse_hex_number

restore_range_start:
                mov      cx,dx
                pop      dx
                pop      ax
                ret      

; Parse a supplied range or reuse the saved offset/segment at DI with CX default count.

parse_opt_range:
                call     skip_opt_comma
                je       reuse_previous_range
                mov      word ptr ds:[def_range_count],cx
                call     parse_range
                jmpn     require_cmd_end

reuse_previous_range:
                mov      si,di
                lodsw    
                mov      dx,ax
                lodsw    
                ret      

; D: display hex/ASCII rows and remember the next dump address.

cmd_dump:
                mov      bp,word ptr ds:[saved_ds]
                mov      cx,word ptr ds:[def_dump_count]
                mov      di,dump_offset
                call     parse_opt_range
                mov      ds,ax
                mov      si,dx

dump_next_row:
                call     print_ds_si
                push     si
                call     print_space

dump_next_hex_byte:
                call     print_space

dump_hex_byte:
                lodsb    
                call     print_hex_byte
                pop      dx
                dec      cx
                je       print_dump_ascii
                mov      ax,si
                test     cs:[dump_line_mask],al
                je       finish_dump_row
                push     dx
                test     al,7
                jne      dump_next_hex_byte
                mov      al,2Dh
                call     print_char
                jmp      short dump_hex_byte

finish_dump_row:
                call     print_dump_ascii
                jmp      short dump_next_row

; Pad the hex columns and print ASCII; nonprinting characters become dots.

print_dump_ascii:
                push     cx
                mov      ax,si
                mov      si,dx
                sub      ax,dx
                mov      bx,ax
                shl      ax,1
                add      ax,bx
                mov      cx,33h
                sub      cx,ax
                call     print_spaces
                mov      cx,bx

dump_ascii_character:
                lodsb    
                and      al,7Fh
                cmp      al,7Fh
                je       replace_nonprinting_byte
                cmp      al,20h
                jae      emit_dump_ascii

replace_nonprinting_byte:
                mov      al,2Eh

emit_dump_ascii:
                call     print_char
                loop     dump_ascii_character
                pop      cx
                mov      word ptr es:[dump_offset],si
                mov      word ptr es:[dump_seg],ds
                jmpn     print_crlf

; M: copy a range; use backward copying when needed to preserve overlapping data.

cmd_move:
                call     parse_ds_range
                push     cx
                push     ax
                push     dx
                call     parse_addr
                call     require_cmd_end
                pop      si
                mov      di,dx
                pop      bx
                mov      ds,bx
                mov      es,ax
                pop      cx
                cmp      di,si
                sbb      ax,bx
                jb       copy_remaining_bytes
                dec      cx
                add      si,cx
                add      di,cx
                std      
                inc      cx

copy_remaining_bytes:
                movsb    
                dec      cx
                rep      movsb

return_common:
                ret      

; F: fill the range with repeated bytes or quoted text from the command buffer.

cmd_fill:
                call     parse_ds_range
                push     cx
                push     ax
                push     dx
                call     parse_byte_list
                pop      di
                pop      es
                pop      cx
                cmp      bx,cx
                mov      si,cmd_buffer
                jcxz     repeat_fill_pattern
                jae      copy_remaining_bytes

repeat_fill_pattern:
                sub      cx,bx
                xchg     bx,cx
                push     di
                rep      movsb
                pop      si
                mov      cx,bx
                push     es
                pop      ds
                jmp      short copy_remaining_bytes

; S: search the range for a byte/string pattern and print every matching address.

cmd_search:
                call     parse_ds_range
                push     cx
                push     ax
                push     dx
                call     parse_byte_list
                dec      bx
                pop      di
                pop      es
                pop      cx
                sub      cx,bx

find_pattern_first_byte:
                mov      si,cmd_buffer
                lodsb    

scan_pattern_first_byte:
                scasb    
                loopne   scan_pattern_first_byte
                jne      return_common
                push     bx
                xchg     cx,bx
                push     di
                repe     cmpsb
                mov      cx,bx
                pop      di
                pop      bx
                jne      continue_search_range
                dec      di
                call     print_es_di
                inc      di
                call     print_crlf

continue_search_range:
                jcxz     return_common
                jmp      short find_pattern_first_byte

; Parse up to CX hexadecimal digits into DX; report missing/overlong values as syntax errors.

parse_hex_number:
                call     skip_opt_comma

parse_hex_digits:
                xor      dx,dx
                call     peek_hex_digit
                jb       syntax_error
                mov      dl,al

parse_next_hex_digit:
                inc      si
                dec      cx
                call     peek_hex_digit
                jb       return_common
                jcxz     syntax_error
                shl      dx,1
                shl      dx,1
                shl      dx,1
                shl      dx,1
                or       dl,al
                jmp      short parse_next_hex_digit

; Peek a hex digit at SI without consuming it. CF marks a non-hex character.

peek_hex_digit:
                mov      al,[si]

convert_hex_digit:
                sub      al,30h
                jb       return_common
                cmp      al,0Ah
                cmc      
                jae      return_common
                and      al,5Fh
                sub      al,7
                cmp      al,0Ah
                jb       return_hex_digit_status
                cmp      al,10h
                cmc      

return_hex_digit_status:
                ret      

; Append a hex byte or quoted string at BX. Doubled quotes represent a literal quote.

parse_byte_or_string:
                call     skip_opt_comma
                call     peek_hex_digit
                jb       test_quoted_byte_list
                mov      cx,2
                call     parse_hex_number
                mov      [bx],dl
                inc      bx

accept_byte_list_item:
                clc      
                ret      

test_quoted_byte_list:
                mov      al,[si]
                cmp      al,27h
                je       begin_byte_list_quote
                cmp      al,22h
                je       begin_byte_list_quote
                stc      
                ret      

begin_byte_list_quote:
                mov      ah,al
                inc      si

read_byte_list_quote:
                lodsb    
                cmp      al,0Dh
                je       syntax_error_previous
                cmp      al,ah
                jne      store_byte_list_character
                cmp      ah,[si]
                jne      accept_byte_list_item
                inc      si

store_byte_list_character:
                mov      [bx],al
                inc      bx
                jmp      short read_byte_list_quote

; Build a nonempty byte/string list in the shared command buffer and require end of command.

parse_byte_list:
                mov      bx,cmd_buffer

parse_next_byte_list_item:
                call     parse_byte_or_string
                jae      parse_next_byte_list_item
                sub      bx,18FDh
                je       syntax_error

require_cmd_end:
                call     skip_whitespace
                jne      syntax_error

require_cmd_end_return:
                ret      

syntax_error_previous:
                dec      si

; Align a caret under the offending command character, report the error, and abandon the command.

syntax_error:
                sub      si,cmd_buffer_before
                mov      cx,si
                call     print_spaces
                mov      si,offset syntax_error_message

print_error_return_prompt:
                call     print_highbit_string
                jmpn     cmd_loop

; Parse [segment:]offset using BP as default segment; CS:/DS:/ES:/SS: use saved target values.

parse_addr:
                call     skip_opt_comma
                mov      al,[si+1]
                cmp      al,53h
                je       parse_saved_segment_name
                mov      cx,4
                call     parse_hex_number
                mov      ax,bp
                cmp82_si 3Ah
                jne      require_cmd_end_return
                push     dx

parse_offset_after_colon:
                inc      si
                mov      cx,4
                call     parse_hex_number
                pop      ax
                ret      

parse_saved_segment_name:
                mov      al,[si]
                mov      di,offset seg_name_letters
                mov      cx,4
                repne    scasb
                jne      syntax_error
                inc      si
                inc      si
                shl      cx,1
                mov      bx,cx
                push     word ptr [bx+saved_ds]
                cmp82_si 3Ah
                jne      syntax_error
                jmp      short parse_offset_after_colon

seg_name_letters                    label byte
                db       "CSED"

enter_byte_list:
                call     parse_byte_list
                pop      di
                pop      es
                mov      si,cmd_buffer
                mov      cx,bx
                rep      movsb
                ret      

; E: write a byte list directly, or edit memory interactively when the list is omitted.

cmd_enter:
                mov      bp,word ptr ds:[saved_ds]
                call     parse_addr
                push     ax
                push     dx
                call     skip_whitespace
                jne      enter_byte_list
                pop      di
                pop      es

enter_display_address:
                call     print_es_di
                call     print_space
                call     print_space

enter_display_current_byte:
                mov      al,es:[di]
                call     print_hex_byte

enter_display_separator:
                mov      al,2Eh
                call     print_char
                mov      cx,2
                mov      dx,0

enter_read_next_nibble:
                call     read_echoed_char
                mov      ah,al
                call     convert_hex_digit
                xchg     ah,al
                jb       enter_dispatch_key
                mov      dh,dl
                mov      dl,ah
                loop     enter_read_next_nibble

enter_read_terminating_key:
                call     read_echoed_char

enter_dispatch_key:
                cmp      al,8
                je       enter_backspace_nibble
                cmp      al,7Fh
                je       enter_erase_delete_key
                cmp      al,2Dh
                je       enter_previous_byte
                cmp      al,0Dh
                je       finish_enter_command
                cmp      al,20h
                je       enter_next_byte
                mov      al,8
                call     print_char
                call     erase_echoed_char
                jcxz     enter_read_terminating_key
                jmp      short enter_read_next_nibble

enter_erase_delete_key:
                mov      al,8
                call     print_char

enter_backspace_nibble:
                cmp82_cl 2
                je       enter_display_separator
                inc      cl
                mov      dl,dh
                mov      dh,ch
                call     erase_echoed_char
                jmp      short enter_read_next_nibble

; Commit the entered nibbles when present; advance DI to the next byte.

commit_entered_byte:
                cmp82_cl 2
                je       advance_enter_address
                push     cx
                mov      cl,4
                shl      dh,cl
                pop      cx
                or       dl,dh
                mov      byte ptr es:[di],dl

advance_enter_address:
                inc      di
                ret      

enter_next_byte:
                call     commit_entered_byte
                inc      cx
                inc      cx
                call     print_spaces
                mov      ax,di
                and      al,7
                jne      enter_display_current_byte

enter_new_row:
                call     print_crlf
                jmpn     enter_display_address

enter_previous_byte:
                call     commit_entered_byte
                dec      di
                dec      di
                jmp      short enter_new_row

finish_enter_command:
                call     commit_entered_byte
                jmpn     print_crlf

read_echoed_char:
                mov      ah,1
                int      21h
                ret      

; Display saved target registers/flags and the instruction at saved CS:IP.

display_regs:
                mov      si,offset reg_names
                mov      bx,offset saved_ax
                mov      byte ptr ds:[regs_remaining],0Dh
                mov      ch,0
                mov      cl,ds:[regs_per_row]

display_register_row:
                sub      ds:[regs_remaining],cl
                call     print_reg_row
                call     print_crlf
                mov      ch,0
                mov      cl,ds:[regs_per_row]
                cmp      cl,ds:[regs_remaining]
                jl       display_register_row
                mov      cl,ds:[regs_remaining]
                call     print_reg_row
                call     print_space
                call     display_flags
                call     print_crlf
                mov      ax,word ptr ds:[saved_ip]
                mov      word ptr ds:[unassemble_offset],ax
                push     ax
                mov      ax,word ptr ds:[saved_cs]
                mov      word ptr ds:[unassemble_seg],ax
                push     ax
                mov      word ptr ds:[def_op_seg],0FFFFh
                call     disasm_insn
                pop      word ptr ds:[unassemble_seg]
                pop      word ptr ds:[unassemble_offset]
                mov      ax,word ptr ds:[def_op_seg]
                cmp      al,0FFh
                je       finish_register_display
                cmp82_ah 0FFh
                je       select_operand_segment
                xchg     al,ah

select_operand_segment:
                cbw      
                mov      bx,ax
                shl      bx,1
                mov      ax,word ptr [bx+seg_reg_names]
                call     print_char
                xchg     al,ah
                call     print_char
                mov      al,3Ah
                call     print_char
                mov      dx,word ptr ds:[effective_addr]
                call     print_hex_word
                mov      al,3Dh
                call     print_char
                mov      bx,word ptr [bx+seg_reg_pointers]
                push     ds
                mov      ds,[bx]
                mov      bx,dx
                mov      dx,word ptr [bx]
                pop      ds
                test     byte ptr ds:[op_is_word],0FFh
                je       display_byte_operand_value
                call     print_hex_word

finish_register_display:
                jmpn     print_crlf

display_byte_operand_value:
                mov      al,dl
                call     print_hex_byte
                jmpn     print_crlf

display_all_registers:
                jmpn     display_regs

; R: select a saved register or flags, display it, then accept a replacement value.

cmd_regs:
                call     skip_opt_comma
                je       display_all_registers
                mov      dl,[si]
                inc      si
                mov      dh,[si]
                cmp82_dh 0Dh
                je       test_flags_register
                inc      si
                call     require_cmd_end
                cmp82_dh 20h
                je       test_flags_register
                mov      di,offset reg_names
                xchg     dx,ax
                push     cs
                pop      es
                mov      cx,0Eh
                repne    scasw
                jne      bad_register_error
                or       cx,cx
                jne      display_selected_register
                dec      di
                dec      di
                mov      ax,word ptr cs:[di-2]

display_selected_register:
                call     print_char
                mov      al,ah
                call     print_char
                call     print_space
                push     ds
                pop      es
                lea      bx,[di+saved_ax-reg_names-2]
                mov      dx,word ptr [bx]
                call     print_hex_word
                call     print_crlf
                mov      al,3Ah
                call     print_char
                call     read_cmd_line
                call     skip_whitespace
                je       return_register_command
                mov      cx,4
                call     parse_hex_digits
                call     require_cmd_end
                mov      [bx],dx

return_register_command:
                ret      

bad_register_error:
                mov      ax,5242h
                jmpn     print_two_letter_error

test_flags_register:
                cmp82_dl 46h
                jne      bad_register_error
                call     display_flags
                mov      al,2Dh
                call     print_char
                call     read_cmd_line
                call     skip_whitespace
                xor      bx,bx
                mov      dx,word ptr ds:[saved_flags]

parse_flag_name_pair:
                lodsw    
                cmp      al,0Dh
                je       save_target_flags
                cmp82_ah 0Dh
                je       bad_flag_error
                mov      di,offset flag_set_names
                mov      cx,20h
                push     cs
                pop      es
                repne    scasw
                jne      bad_flag_error
                mov      ch,cl
                and      cl,0Fh
                mov      ax,1
                rol      ax,cl
                test_bx_ax 
                jne      duplicate_flag_error
                or       bx,ax
                or       dx,ax
                test     ch,10h
                jne      parse_next_flag_pair
                xor      dx,ax

parse_next_flag_pair:
                call     skip_opt_comma
                jmp      short parse_flag_name_pair

; CS:SI names registers; BX addresses their saved words. Print CX name=value pairs.

print_reg_row:
                lodsw_cs 
                call     print_char
                mov      al,ah
                call     print_char
                mov      al,3Dh
                call     print_char
                mov      dx,word ptr [bx]
                inc      bx
                inc      bx
                call     print_hex_word
                call     print_space
                call     print_space
                loop     print_reg_row
                ret      

duplicate_flag_error:
                mov      ax,4644h

save_flags_before_error:
                call     save_target_flags

print_two_letter_error:
                call     print_char
                mov      al,ah
                call     print_char
                mov      si,offset reg_error_suffix
                jmpn     print_error_return_prompt

save_target_flags:
                mov      word ptr ds:[saved_flags],dx
                ret      

bad_flag_error:
                mov      ax,4642h
                jmp      short save_flags_before_error

; Select set/clear flag-name pairs by shifting the saved flags through carry.

display_flags:
                mov      si,offset flag_set_names
                mov      cx,10h
                mov      dx,word ptr ds:[saved_flags]

select_flag_name:
                lodsw_cs 
                shl      dx,1
                jb       emit_visible_flag_name
                mov      ax,word ptr cs:[si+1Eh]

emit_visible_flag_name:
                or       ax,ax
                je       advance_flag_bit
                call     print_char
                mov      al,ah
                call     print_char
                call     print_space

advance_flag_bit:
                loop     select_flag_name
                ret      

; T: set the target trap flag and execute the requested number of instructions.

cmd_trace:
                call     parse_execution_addr
                call     skip_opt_comma
                call     peek_hex_digit
                mov      dx,1
                jb       save_requested_trace_count
                mov      cx,4
                call     parse_hex_number

save_requested_trace_count:
                mov      word ptr ds:[trace_count],dx
                call     require_cmd_end

resume_single_step:
                mov      word ptr ds:[breakpt_count],0
                or       byte ptr ds:[saved_flags_high],1

; Install DEBUG handlers for INT 1, INT 3 and Ctrl-Break while the target executes.

install_debug_traps:
                push     ds
                xor      ax,ax
                mov      ds,ax
                mov      word ptr ds:[ivt_breakpt_offset],offset breakpt_trap
                mov      word ptr ds:[ivt_breakpt_segment],cs
                mov      word ptr ds:[4],offset capture_target_regs
                mov      word ptr ds:[6],cs
                cli      
                mov      word ptr ds:[ivt_ctrl_break_offset],offset target_control_break
                mov      word ptr ds:[ivt_ctrl_break_segment],cs
                pop      ds

; Pop the saved register image and build FLAGS/CS/IP for IRET into the target.

restore_target_regs:
                mov      sp,offset saved_ax
                pop      ax
                pop      bx
                pop      cx
                pop      dx
                pop      bp
                pop      bp
                pop      si
                pop      di
                pop      es
                pop      es
                pop      ss
                mov      sp,word ptr ds:[saved_sp]
                push     word ptr ds:[saved_flags]
                push     word ptr ds:[saved_cs]
                push     word ptr ds:[saved_ip]
                mov      ds,ds:[saved_ds]
                iret     

display_next_trace:
                call     print_crlf
                call     display_regs
                jmp      short resume_single_step

; Execution-time Ctrl-Break discards the interrupt frame before entering common capture.

target_control_break:
                add      sp,6
                jmp      short capture_target_regs

; INT 3 returns after the CC byte. Back up target IP so the original instruction can resume.

breakpt_trap:
                xchg     bp,sp
                dec      word ptr [bp]
                xchg     bp,sp

; Capture target registers on DEBUG storage, then recover CS:IP/FLAGS from its interrupt stack.

capture_target_regs:
                mov      word ptr cs:[saved_sp],sp
                mov      word ptr cs:[saved_ss],ss
                mov      sp,cs
                mov      ss,sp
                mov      sp,offset saved_ss
                push     es
                push     ds
                push     di
                push     si
                push     bp
                dec      sp
                dec      sp
                push     dx
                push     cx
                push     bx
                push     ax
                push     ss
                pop      ds
                mov      sp,word ptr ds:[saved_sp]
                mov      ss,ds:[saved_ss]
                pop      word ptr ds:[saved_ip]
                pop      word ptr ds:[saved_cs]
                pop      ax
                and      ah,0FEh
                mov      word ptr ds:[saved_flags],ax
                mov      word ptr ds:[saved_sp],sp
                push     ds
                pop      es
                push     ds
                pop      ss

restore_debug_stack:
                mov      sp,offset saved_ax
                push     ds
                xor      ax,ax
                mov      ds,ax
                mov      word ptr ds:[ivt_ctrl_break_offset],offset control_break
                mov      word ptr ds:[ivt_ctrl_break_segment],cs
                pop      ds
                sti      
                cld      
                dec      word ptr ds:[trace_count]
                jne      display_next_trace

; Restore the original byte at every temporary breakpoint before returning to the prompt.

restore_breakpt_bytes:
                mov      si,breakpt_table
                mov      cx,word ptr ds:[breakpt_count]
                jcxz     display_stopped_program
                push     es

restore_breakpt_bytes_les:
                les      di,dword ptr [si]
                add      si,4
                movsb    
                loop     restore_breakpt_bytes_les
                pop      es

display_stopped_program:
                call     print_crlf
                call     display_regs
                jmpn     cmd_loop

; I: read a byte from the specified hardware port and print it.

cmd_input_port:
                mov      cx,4
                call     parse_hex_number
                call     require_cmd_end
                in       al,dx
                call     print_hex_byte
                jmpn     print_crlf

; O: parse a port and byte, then write that byte with OUT.

cmd_output_port:
                mov      cx,4
                call     parse_hex_number
                push     dx
                mov      cx,2
                call     parse_hex_number
                call     require_cmd_end
                xchg     dx,ax
                pop      dx
                out      dx,al

keep_execution_address:
                ret      

; An optional =address replaces the saved execution CS:IP; otherwise leave it unchanged.

parse_execution_addr:
                mov      bp,word ptr ds:[saved_cs]
                call     skip_opt_comma
                cmp82_si 3Dh
                jne      keep_execution_address
                inc      si
                call     parse_addr
                mov      word ptr ds:[saved_cs],ax
                mov      word ptr ds:[saved_ip],dx
                ret      

; G: parse up to ten breakpoint addresses, save their original bytes, and insert CC opcodes.

cmd_go:
                call     parse_execution_addr
                xor      bx,bx
                mov      di,breakpt_table

parse_next_breakpoint:
                call     skip_opt_comma
                je       install_breakpts
                mov      bp,word ptr ds:[saved_cs]
                call     parse_addr
                mov      [di],dx
                mov      [di+2],ax
                add      di,5
                inc      bx
                cmp      bx,0Bh
                jne      parse_next_breakpoint
                mov      ax,5042h
                jmpn     print_two_letter_error

install_breakpts:
                mov      word ptr ds:[breakpt_count],bx
                mov      cx,bx
                jcxz     resume_until_breakpoint
                mov      di,breakpt_table
                push     ds

install_breakpts_lds:
                lds      si,dword ptr es:[di]
                add      di,4
                movsb    
                mov      byte ptr [si-1],0CCh
                loop     install_breakpts_lds
                pop      ds

resume_until_breakpoint:
                mov      word ptr ds:[trace_count],1
                jmpn     install_debug_traps

; Copy the command tail into the target PSP and parse its two default FCBs.

copy_target_cmd_tail:
                mov      es,ds:[saved_ds]
                push     si
                mov      di,psp_cmd_tail

copy_target_tail_character:
                lodsb    
                stosb    
                cmp      al,0Dh
                jne      copy_target_tail_character
                sub      di,82h
                xchg     di,ax
                mov      byte ptr es:[psp_cmd_length],al
                pop      si
                mov      di,file_fcb
                mov      ax,2901h
                int      21h
                mov      byte ptr ds:[saved_ax],al
                mov      ax,2901h
                mov      di,second_default_fcb
                int      21h
                mov      byte ptr ds:[saved_ah],al
                ret      

; N: update the target tail/FCBs and retain the filename in DEBUG PSP for later L/W.

cmd_name:
                call     copy_target_cmd_tail
                mov      al,byte ptr ds:[saved_ax]
                mov      byte ptr ds:[filename_parse_status],al
                push     es
                pop      ds
                push     cs
                pop      es
                mov      si,file_fcb
                mov      di,si
                mov      cx,6
                rep      movsw

return_file_helper:
                ret      

invalid_drive:
                mov      dx,offset invalid_drive_message
                jmpn     print_dos_error

; Validate the saved filename parse status and test its extension for HEX.

test_hex_extension:
                cmp82_mem filename_parse_status, 0FFh
                je       invalid_drive
                cmp      word ptr ds:[file_extension],4548h
                jne      return_file_helper
                cmp82_mem file_extension_last, 58h
                ret      

; Restore DOS DTA to target PSP:0080 after temporary file/header buffers.

restore_target_dta:
                push     ds
                mov      ds,ds:[saved_ds]
                mov      dx,80h
                mov      ah,1Ah
                int      21h
                pop      ds
                ret      

cmd_load:
                mov      byte ptr ds:[file_transfer_function],dos_read_block
                jmp      short parse_file_or_disk_request

cmd_write:
                mov      byte ptr ds:[file_transfer_function],dos_write_block

; L/W: distinguish a file operation from the address/drive/sector/count disk syntax.

parse_file_or_disk_request:
                mov      bp,word ptr ds:[saved_cs]
                call     skip_whitespace
                je       load_at_def_addr
                call     parse_addr
                call     skip_whitespace
                je       load_at_given_addr
                push     ax
                mov      bx,dx
                mov      cx,1
                call     parse_hex_number
                push     dx
                mov      cx,4
                call     parse_hex_number
                push     dx
                mov      cx,3
                call     parse_hex_number
                call     require_cmd_end
                mov      cx,dx
                pop      dx
                pop      ax
                cbw      
                mov      byte ptr ds:[disk_error_drive],al
                pop      ds
                cmp82_cs_mem file_transfer_function,dos_write_block
                je       write_absolute_disk_sectors
                int      25h
                jmp      short test_absolute_disk_result

write_absolute_disk_sectors:
                int      26h

test_absolute_disk_result:
                jae      discard_absolute_disk_flags

; INT 25h/26h leave FLAGS on the stack; report disk errors with drive and read/write context.

disk_transfer_error:
                mov      dx,offset disk_error_word
                or       al,al
                jne      format_disk_error_context
                mov      dx,offset write_protect_word

format_disk_error_context:
                push     cs
                pop      ds
                push     cs
                pop      es
                add82_mem disk_error_drive, 41h
                mov      si,offset read_verb
                mov      di,offset disk_error_verb
                cmp82_mem file_transfer_function, dos_write_block
                jne      copy_disk_error_verb
                mov      si,offset write_verb

copy_disk_error_verb:
                movsw    
                movsw    
                mov      ah,9
                int      21h
                mov      dx,offset disk_error_context
                jmpn     print_dos_error

discard_absolute_disk_flags:
                popf     
                ret      

load_at_def_addr:
                mov      ax,word ptr ds:[saved_cs]
                mov      dx,offset start
                call     test_hex_extension
                jne      begin_file_transfer
                xor      dx,dx

select_hex_transfer:
                jmpn     transfer_hex_file

load_at_given_addr:
                call     test_hex_extension
                je       select_hex_transfer

; Clear random-record position and select flat binary or EXE handling from the extension.

begin_file_transfer:
                xor      bx,bx
                mov      word ptr ds:[fcb_random_record_low],bx
                mov      word ptr ds:[fcb_random_record_high],bx
                cmp      word ptr ds:[file_extension],5845h
                jne      save_file_destination
                cmp82_mem file_extension_last, 45h
                jne      save_file_destination
                jmpn     load_exe_file

save_file_destination:
                push     ax
                push     dx
                mov      dx,file_fcb
                cmp82_mem file_transfer_function, dos_write_block
                je       create_output_file
                mov      ah,0Fh
                int      21h
                or       al,al
                jne      file_not_found
                mov      word ptr ds:[fcb_record_size],1
                mov      si,0FFFFh
                mov      di,si
                pop      dx
                pop      ax
                call     transfer_file_blocks
                not      si
                not      di
                mov      word ptr ds:[saved_cx],di
                mov      word ptr ds:[saved_bx],si
                jmpn     restore_target_dta

; Transfer one-byte FCB records in chunks, normalizing segment:offset across 64 KiB boundaries.

transfer_file_blocks:
                mov      bx,dx
                and      dx,0Fh
                mov      cl,4
                shr      bx,cl
                add      ax,bx
                push     ax
                push     dx
                push     ds
                mov      ds,ax
                mov      ah,1Ah
                int      21h
                pop      ds
                mov      dx,file_fcb
                mov      cx,0FFF0h
                or       si,si
                jne      transfer_next_file_chunk
                mov      cx,di

transfer_next_file_chunk:
                mov      ah,ds:[file_transfer_function]
                int      21h
                sub      di,cx
                sbb      si,0
                cmp      al,1
                pop      dx
                pop      ax
                je       finish_file_transfer
                add      dx,cx
                mov      bx,si
                or       bx,di
                jne      transfer_file_blocks

finish_file_transfer:
                stc      
                ret      

file_not_found:
                mov      dx,offset file_not_found_message

report_file_error:
                jmpn     print_dos_error

; Create a binary output file and write the byte count held in target BX:CX.

create_output_file:
                mov      ah,16h
                int      21h
                inc      al
                mov      dx,offset directory_full_message
                je       report_file_error
                mov      word ptr ds:[fcb_record_size],1
                mov      si,word ptr ds:[saved_bx]
                cmp      si,0Fh
                jle      display_output_byte_count
                xor      si,si

display_output_byte_count:
                mov      dx,offset writing_message
                mov      ah,9
                int      21h
                or       si,si
                je       display_output_low_count
                mov      ax,si
                call     print_hex_nibble

display_output_low_count:
                mov      dx,word ptr ds:[saved_cx]
                mov      di,dx
                call     print_hex_word
                mov      dx,offset bytes_message
                mov      ah,9
                int      21h
                pop      dx
                pop      ax
                call     transfer_file_blocks
                jb       close_output_file
                mov      dx,offset disk_full_message
                mov      ah,9
                int      21h

close_output_file:
                mov      ah,10h
                mov      dx,file_fcb
                int      21h
                jmpn     restore_target_dta

; Load an EXE header, choose a suitable image segment, read the image, and apply relocations.

load_exe_file:
                mov      dx,offset cannot_write_exe_message
                cmp82_mem file_transfer_function, 27h
                je       open_executable_input
                jmpn     print_dos_error

open_executable_input:
                mov      dx,exe_header
                mov      ah,1Ah
                int      21h
                mov      cx,1Ah
                mov      dx,file_fcb
                mov      ah,0Fh
                int      21h
                mov      word ptr ds:[fcb_record_size],1
                or       al,al
                je       read_exe_header
                call     restore_target_dta
                jmpn     file_not_found

; Read 26 MZ header bytes; compute file/image length and memory requirements.

read_exe_header:
                mov      ah,27h
                int      21h
                mov      ax,word ptr ds:[exe_header_paragraphs]
                add      ax,1Fh
                mov      cl,4
                rol      ax,cl
                mov      bx,ax
                and      ax,0FE00h
                and      bx,0Fh
                mov      word ptr ds:[fcb_random_record_low],ax
                mov      word ptr ds:[fcb_random_record_high],bx
                mov      dx,word ptr ds:[exe_page_count]
                dec      dx
                xchg     dh,dl
                rol      dx,1
                mov      di,dx
                mov      si,dx
                and      di,0FE00h
                and      si,1FFh
                sub      di,ax
                sbb      si,bx
                mov      ax,word ptr ds:[exe_last_page_bytes]
                cmp      ax,4
                je       use_full_final_page
                or       ax,ax
                jne      add_executable_final_bytes

use_full_final_page:
                mov      ax,200h

add_executable_final_bytes:
                add      di,ax
                adc      si,0
                mov      ax,di
                add      ax,0Fh
                and      al,0F0h
                or       ax,si
                mov      cl,4
                ror      ax,cl
                xchg     cx,ax
                mov      bx,word ptr ds:[saved_ds]
                add      bx,10h
                mov      ax,word ptr ds:[2]
                sub      ax,cx
                mov      dx,offset memory_error_message
                jb       restore_dta_and_report_error
                cmp      bx,ax
                ja       restore_dta_and_report_error
                cmp      word ptr ds:[exe_max_extra],-1
                jne      select_executable_load_segment
                xchg     bx,ax

select_executable_load_segment:
                mov      bp,ax
                mov      word ptr ds:[saved_bx],si
                mov      word ptr ds:[saved_cx],di
                xor      dx,dx
                call     transfer_file_blocks
                jb       seek_exe_relocations

bad_executable_input:
                mov      dx,offset bad_exe_message

restore_dta_and_report_error:
                push     dx
                call     restore_target_dta
                pop      dx
                jmpn     print_dos_error

; Seek to the relocation table and reuse the header buffer for each offset/segment pair.

seek_exe_relocations:
                mov      ax,word ptr ds:[exe_relocation_offset]
                mov      word ptr ds:[fcb_random_record_low],ax
                mov      word ptr ds:[fcb_random_record_high],0
                mov      dx,exe_header
                mov      ah,1Ah
                int      21h
                cmp      word ptr ds:[exe_relocation_count],0
                je       set_exe_regs

; Add the chosen load segment to each relocated word in the target image.

relocate_exe_word:
                mov      ah,27h
                mov      dx,file_fcb
                mov      cx,4
                int      21h
                or       al,al
                jne      bad_executable_input
                mov      di,word ptr ds:[exe_header]
                mov      ax,word ptr ds:[exe_last_page_bytes]
                add      ax,bp
                mov      es,ax
                add      word ptr es:[di],bp
                dec      word ptr ds:[exe_relocation_count]
                jne      relocate_exe_word

; Set saved SS:SP and CS:IP from the EXE header plus the chosen image segment.

set_exe_regs:
                mov      ax,word ptr ds:[exe_initial_ss]
                add      ax,bp
                mov      word ptr ds:[saved_ss],ax
                mov      ax,word ptr ds:[exe_initial_sp]
                mov      word ptr ds:[saved_sp],ax
                mov      ax,word ptr ds:[exe_initial_cs]
                add      ax,bp
                mov      word ptr ds:[saved_cs],ax
                mov      ax,word ptr ds:[exe_initial_ip]
                mov      word ptr ds:[saved_ip],ax
                jmpn     restore_target_dta

; HEX transfer path: scan colon records, parse bytes, and write them into ES:DI.
; The original accepts function 28h (W) here and rejects 27h (L). This reversed
; HEX dispatch was confirmed against the original in emu2 and is preserved.

transfer_hex_file:
                mov      word ptr ds:[effective_addr],dx
                mov      dx,offset cannot_write_exe_message
                cmp82_mem file_transfer_function, dos_write_block
                je       open_hex_input
                jmpn     report_hex_file_error

open_hex_input:
                mov      es,ax
                mov      dx,hex_input_buffer
                mov      ah,1Ah
                int      21h
                mov      ah,0Fh
                mov      dx,file_fcb
                int      21h
                or       al,al
                mov      dx,offset file_not_found_message
                je       initialize_hex_record_input
                jmpn     restore_dta_and_report_error

initialize_hex_record_input:
                xor      ax,ax
                mov      word ptr ds:[fcb_block],ax
                mov      byte ptr ds:[fcb_current_record],al
                mov      word ptr ds:[fcb_record_size],200h
                mov      ah,14h
                mov      dx,file_fcb
                xor      bp,bp
                mov      si,hex_buffer_end

find_hex_record:
                call     read_hex_char
                cmp      al,3Ah
                jne      find_hex_record
                call     read_hex_byte
                mov      cl,al
                mov      ch,0
                jcxz     finish_hex_input
                call     read_hex_byte
                mov      bh,al
                call     read_hex_byte
                mov      bl,al
                add      bx,word ptr ds:[effective_addr]
                mov      di,bx
                call     read_hex_byte

copy_hex_record_byte:
                call     read_hex_byte
                stosb    
                cmp      di,bp
                jbe      continue_hex_record
                mov      bp,di

continue_hex_record:
                loop     copy_hex_record_byte
                jmp      short find_hex_record

; Fetch the next HEX character, refilling the 512-byte FCB buffer when exhausted.

read_hex_char:
                cmp      si,1AD8h
                jne      consume_hex_buffer_byte
                int      21h
                cmp      al,1
                je       finish_hex_input
                mov      si,hex_input_buffer

consume_hex_buffer_byte:
                lodsb    
                cmp      al,1Ah
                je       finish_hex_input
                or       al,al
                jne      return_transfer_helper

finish_hex_input:
                mov      word ptr ds:[saved_cx],bp
                mov      word ptr ds:[saved_bx],0
                jmpn     restore_target_dta

; Read and validate one hexadecimal digit from the HEX stream.

read_hex_digit:
                call     read_hex_char
                call     convert_hex_digit
                jae      return_transfer_helper
                mov      dx,offset bad_exe_message

report_hex_file_error:
                jmpn     print_dos_error

; Combine two validated digits into one byte in AL.

read_hex_byte:
                call     read_hex_digit
                mov      bl,al
                call     read_hex_digit
                shl      bl,1
                shl      bl,1
                shl      bl,1
                shl      bl,1
                or       al,bl

return_transfer_helper:
                ret      

; C: compare two memory ranges and display both addresses and bytes for each mismatch.

cmd_compare:
                call     parse_ds_range
                push     cx
                push     ax
                push     dx
                call     parse_addr
                call     require_cmd_end
                pop      si
                mov      di,dx
                mov      es,ax
                pop      ds
                pop      cx
                dec      cx
                call     compare_memory_bytes
                inc      cx

compare_memory_bytes:
                repe     cmpsb
                je       return_transfer_helper
                dec      si
                call     print_ds_si
                call     print_space
                call     print_space
                lodsb    
                call     print_hex_byte
                call     print_space
                call     print_space
                dec      di
                mov      al,es:[di]
                call     print_hex_byte
                call     print_space
                call     print_space
                call     print_es_di
                inc      di
                call     print_crlf
                xor      al,al
                jmp      short compare_memory_bytes

; U: disassemble a range and retain the next instruction address for another U command.

cmd_unassemble:
                mov      bp,word ptr ds:[saved_cs]
                mov      di,unassemble_offset
                mov      cx,word ptr ds:[def_dump_count]
                shr      cx,1
                shr      cx,1
                call     parse_opt_range
                mov      word ptr ds:[unassemble_offset],dx
                mov      word ptr ds:[unassemble_seg],ax
                mov      word ptr ds:[unassemble_remaining],cx

unassemble_next_instruction:
                call     disasm_insn
                call     print_crlf
                test     word ptr ds:[unassemble_remaining],0FFFFh
                jne      unassemble_next_instruction
                ret      

; Fetch from the target CS:IP cursor, echo its hex byte, and update byte/range counts.

fetch_insn_byte:
                push     ds
                lds      si,dword ptr ds:[unassemble_offset]
                lodsb    
                pop      ds
                mov      word ptr ds:[unassemble_offset],si
                push     ax
                call     print_hex_byte
                mov      si,word ptr ds:[unassemble_remaining]
                or       si,si
                je       count_instruction_byte
                dec      si
                mov      word ptr ds:[unassemble_remaining],si

count_instruction_byte:
                inc      byte ptr ds:[insn_byte_count]
                pop      ax
                ret      

; Segment override: save its selector, discard this handler return, and finish prefix output.

decode_seg_override:
                call     decode_seg_reg
                mov      byte ptr ds:[override_seg],al

finish_prefix_output:
                pop      bx
                call     print_disasm_line
                call     print_crlf

; Read an opcode and dispatch through its mnemonic/handler entry in opcode_dispatch.

disasm_insn:
                push     ds
                lds      si,dword ptr ds:[unassemble_offset]
                call     print_ds_si
                pop      ds
                call     print_space
                mov      byte ptr ds:[insn_byte_count],0
                mov      di,op_text
                mov      al,20h
                mov      cx,17h
                rep      stosb
                mov      byte ptr [di],0A0h
                call     fetch_insn_byte
                mov      ah,0
                mov      bx,ax
                and      al,1
                mov      byte ptr ds:[op_is_word],al
                mov      al,bl
                shl      bx,1
                shl      bx,1
                add      bx,10A4h
                mov      dx,word ptr [bx]
                mov      word ptr ds:[current_mnemonic],dx
                mov      di,op_text
                call     word ptr [bx+2]

; Pad the instruction bytes, then print the selected mnemonic and constructed operand string.

print_disasm_line:
                mov      si,unassemble_offset
                mov      ah,ds:[insn_byte_count]
                add      ah,ah
                mov      al,0Eh
                sub      al,ah
                cbw      
                xchg     cx,ax
                call     print_spaces
                mov      si,word ptr ds:[current_mnemonic]
                call     print_highbit_string
                mov      al,9
                call     print_char
                mov      si,op_text
                jmpn     print_highbit_string

; Split the following ModR/M byte into r/m, reg and mode fields.

decode_modrm:
                call     fetch_insn_byte
                mov      ah,al
                and      al,7
                mov      byte ptr ds:[modrm_rm],al
                shr      ah,1
                shr      ah,1
                shr      ah,1
                mov      al,ah
                and      al,7
                mov      byte ptr ds:[modrm_reg],al
                shr      ah,1
                shr      ah,1
                shr      ah,1
                mov      byte ptr ds:[modrm_mode],ah
                ret      

; Group 1: select the arithmetic mnemonic from ModR/M, then format r/m and immediate.

decode_group1_imm:
                mov      bx,offset arithmetic_mnemonics
                call     select_group_mnemonic

format_group1_size:
                call     append_op_size
                jmp      short append_immediate_separator

decode_modrm_imm:
                call     decode_modrm
                jmp      short format_group1_size

decode_accumulator_imm:
                xor      al,al

append_opcode_register:
                call     append_reg

append_immediate_separator:
                mov      al,2Ch
                stosb    
                test     byte ptr ds:[op_is_word],0FFh
                jne      append_word_imm

append_byte_imm:
                call     fetch_insn_byte
                jmp      short append_hex_byte

; Fetch far offset and segment words; print them in segment:offset order.

append_far_pointer:
                push     di
                mov      di,far_pointer_work
                call     append_word_imm
                pop      di
                call     append_word_imm
                mov      al,3Ah
                stosb    
                mov      si,far_pointer_work
                mov      cx,4

append_far_offset_digits:
                lodsb    
                stosb    
                loop     append_far_offset_digits
                ret      

; Fetch a little-endian word and append four hexadecimal digits.

append_word_imm:
                call     fetch_insn_byte
                mov      dl,al
                call     fetch_insn_byte
                mov      dh,al
                call     append_hex_byte
                mov      al,dl

; Append AL as two hex digits at ES:DI; preserve the original DAA conversion.

append_hex_byte:
                mov      ah,al
                shr      al,1
                shr      al,1
                shr      al,1
                shr      al,1
                call     append_hex_nibble
                mov      al,ah

append_hex_nibble:
                and      al,0Fh
                add      al,90h
                daa      
                adc      al,40h
                daa      
                stosb    
                ret      

decode_aam_aad_base:
                call     fetch_insn_byte
                cmp      al,0Ah
                jne      append_hex_byte
                ret      

decode_group1_signed:
                mov      bx,offset arithmetic_mnemonics
                call     select_group_mnemonic
                call     append_op_size
                mov      al,2Ch
                stosb    

; Sign-extend an 8-bit displacement and append its explicit + or - magnitude.

append_signed_disp:
                call     fetch_insn_byte
                cbw      
                mov      dx,ax
                mov      ah,al
                mov      al,2Bh
                or       ah,ah
                jns      append_displacement_sign
                mov      al,2Dh
                neg      ah

append_displacement_sign:
                stosb    
                mov      al,ah
                jmp      short append_hex_byte

decode_rm_reg:
                call     decode_rm_op
                mov      al,2Ch
                stosb    

append_reg_field:
                mov      al,ds:[modrm_reg]

; Append one register name; operand_is_word selects the byte or word table.

append_reg:
                mov      si,offset byte_reg_names
                cmp82_mem op_is_word, 1
                jne      copy_encoded_register_name

append_word_reg:
                mov      si,offset word_reg_names

copy_encoded_register_name:
                cbw      
                add      si,ax
                add      si,ax
                movsw    
                ret      

decode_seg_reg:
                shr      al,1
                shr      al,1
                shr      al,1

append_seg_reg:
                and      al,3
                mov      si,offset seg_reg_names
                jmp      short copy_encoded_register_name

decode_word_reg:
                and      al,7
                jmp      short append_word_reg

decode_rm_seg:
                mov      byte ptr ds:[op_is_word],1
                call     decode_rm_op
                mov      al,2Ch
                stosb    
                mov      al,ds:[modrm_reg]
                jmp      short append_seg_reg

decode_seg_rm:
                call     decode_modrm
                call     append_seg_reg
                mov      byte ptr ds:[op_is_word],1
                jmp      short append_comma_rm

decode_rm_op:
                call     decode_modrm
                jmp      short append_rm_op

decode_reg_rm:
                mov      byte ptr ds:[op_is_word],1

decode_reg_rm_fields:
                call     decode_modrm
                call     append_reg_field

append_comma_rm:
                mov      al,2Ch
                stosb    

; Format ModR/M r/m: register mode, direct address, or 8086 base/index plus displacement.

append_rm_op:
                cmp82_mem modrm_mode, 3
                mov      al,ds:[modrm_rm]
                je       append_reg
                xor      bx,bx
                mov      byte ptr ds:[def_op_seg],3
                mov      byte ptr [di],5Bh
                inc      di
                cmp      al,6
                jne      select_address_base_register
                cmp82_mem modrm_mode, 0
                je       append_direct_address_word

select_address_base_register:
                mov      dl,al
                cmp      al,1
                jbe      use_bx_based_address
                cmp      al,7
                je       use_bx_based_address
                cmp      al,3
                jbe      use_bp_based_address
                cmp      al,6
                jne      test_address_index_needed

use_bp_based_address:
                mov      bx,word ptr ds:[saved_bp]
                mov      byte ptr ds:[def_op_seg],2
                mov      ax,5042h

append_rm_op_stosw:
                stosw    

test_address_index_needed:
                cmp82_dl 4
                jae      test_address_index_register
                mov      al,2Bh
                stosb    

test_address_index_register:
                cmp82_dl 6
                jae      append_modrm_displacement
                and      dl,1
                je       use_si_index_register
                add      bx,word ptr ds:[saved_di]
                mov      ax,4944h

append_rm_op_stosw_2:
                stosw    

append_modrm_displacement:
                mov      al,ds:[modrm_mode]
                or       al,al
                je       close_memory_operand
                cmp      al,2
                je       append_word_displacement_sign
                call     append_signed_disp

add_effective_displacement:
                add      bx,dx

close_memory_operand:
                mov      al,5Dh
                stosb    
                mov      word ptr ds:[effective_addr],bx

return_op:
                ret      

append_word_displacement_sign:
                mov      al,2Bh
                stosb    

append_direct_address_word:
                call     append_word_imm
                jmp      short add_effective_displacement

use_bx_based_address:
                mov      bx,word ptr ds:[saved_bx]
                mov      ax,5842h
                jmp      short append_rm_op_stosw

use_si_index_register:
                add      bx,word ptr ds:[saved_si]
                mov      ax,4953h
                jmp      short append_rm_op_stosw_2

; Short relative branch: add the signed byte to the updated instruction cursor.

decode_short_rel:
                call     fetch_insn_byte
                cbw      
                add      ax,word ptr ds:[unassemble_offset]
                xchg     dx,ax

append_relative_target:
                mov      al,dh
                call     append_hex_byte
                mov      al,dl
                jmpn     append_hex_byte

; Near relative branch: add the word displacement to the updated instruction cursor.

decode_near_rel:
                call     fetch_insn_byte
                mov      dl,al
                call     fetch_insn_byte
                mov      dh,al
                add      dx,word ptr ds:[unassemble_offset]
                jmp      short append_relative_target

decode_accumulator_exchange:
                and      al,7
                call     append_word_reg
                mov      al,2Ch
                stosb    
                xor      al,al
                jmpn     append_word_reg

decode_accumulator_memory:
                xor      al,al
                call     append_reg
                mov      al,2Ch
                stosb    

append_direct_memory:
                mov      al,5Bh
                stosb    
                xor      bx,bx
                mov      byte ptr ds:[def_op_seg],3
                jmpn     append_direct_address_word

decode_memory_accumulator:
                call     append_direct_memory
                mov      al,2Ch
                stosb    
                xor      al,al
                jmpn     append_reg

decode_byte_reg_imm:
                mov      byte ptr ds:[op_is_word],0
                jmp      short decode_word_reg_imm_and

decode_word_reg_imm:
                mov      byte ptr ds:[op_is_word],1

decode_word_reg_imm_and:
                and      al,7
                jmpn     append_opcode_register

decode_long_return:
                mov      al,4Ch
                stosb    
                ret      

decode_far_return:
                mov      ax,2C4Ch
                stosw    
                jmpn     append_word_imm

decode_int3:
                mov      byte ptr [di],33h
                ret      

decode_escape:
                and      al,7
                mov      dl,al
                call     decode_modrm
                shl      dl,1
                shl      dl,1
                shl      dl,1
                or       al,dl
                call     append_hex_byte
                cmp82_mem modrm_mode, 3
                je       append_escape_register
                mov      byte ptr ds:[op_is_word],1
                jmpn     append_comma_rm

append_escape_register:
                mov      al,2Ch
                stosb    
                mov      al,ds:[modrm_rm]
                and      al,7
                jmpn     append_hex_byte

decode_dx_port:
                mov      word ptr [di],5844h
                ret      

decode_group2:
                mov      bx,offset shift_mnemonics
                call     select_group_mnemonic

; Add B,/W, for memory operands when their size is not implied by a register.

append_op_size:
                cmp82_mem modrm_mode, 3
                je       format_sized_rm_operand
                mov      ax,2C42h
                test     byte ptr ds:[op_is_word],0FFh
                je       store_operand_size_marker
                mov      al,57h

store_operand_size_marker:
                stosw    

format_sized_rm_operand:
                jmpn     append_rm_op

decode_shift_count:
                call     decode_group2
                mov      al,2Ch
                stosb    
                mov      word ptr [di],4C43h
                ret      

; Use the ModR/M reg field to select a grouped opcode mnemonic.

select_group_mnemonic:
                call     decode_modrm
                mov      dl,al
                cbw      
                shl      ax,1
                add      bx,ax
                mov      ax,word ptr [bx]
                mov      word ptr ds:[current_mnemonic],ax
                mov      al,dl
                ret      

; Group 3: TEST/NOT/NEG/MUL/IMUL/DIV/IDIV, with immediate only for TEST.

decode_group3:
                mov      bx,offset unary_mnemonics
                call     select_group_mnemonic
                or       al,al
                je       format_test_immediate
                cmp      al,4
                jb       append_op_size
                xor      al,al
                call     append_reg
                jmpn     append_comma_rm

format_test_immediate:
                jmpn     format_group1_size

; Groups 4/5: INC/DEC/CALL/JMP/PUSH, adding the long marker for far forms.

decode_group45:
                mov      bx,offset group45_mnemonics
                call     select_group_mnemonic
                cmp      al,2
                jb       append_op_size
                cmp      al,6
                jae      format_group45_rm_operand
                test     al,1
                je       format_group45_rm_operand
                mov      ax,2C4Ch
                stosw    

format_group45_rm_operand:
                jmpn     append_rm_op

; Two-byte register names indexed by opcode/ModR/M fields.

byte_reg_names                      label byte
                db       "ALCLDLBLAHCHDHBH"

word_reg_names                      label byte
                db       "AXCXDXBXSPBPSIDI"

seg_reg_names                       label byte
                db       "ESCSSSDS"

; 256 entries, indexed by opcode*4: mnemonic pointer followed by formatting callback.

opcode_dispatch                     label word
                dw       offset mnemonic_add
                dw       offset decode_rm_reg
                dw       offset mnemonic_add
                dw       offset decode_rm_reg
                dw       offset mnemonic_add
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_add
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_add
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_add
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_push
                dw       offset decode_seg_reg
                dw       offset mnemonic_pop
                dw       offset decode_seg_reg
                dw       offset mnemonic_or
                dw       offset decode_rm_reg
                dw       offset mnemonic_or
                dw       offset decode_rm_reg
                dw       offset mnemonic_or
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_or
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_or
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_or
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_push
                dw       offset decode_seg_reg
                dw       offset mnemonic_pop
                dw       offset decode_seg_reg
                dw       offset mnemonic_adc
                dw       offset decode_rm_reg
                dw       offset mnemonic_adc
                dw       offset decode_rm_reg
                dw       offset mnemonic_adc
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_adc
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_adc
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_adc
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_push
                dw       offset decode_seg_reg
                dw       offset mnemonic_pop
                dw       offset decode_seg_reg
                dw       offset mnemonic_sbb
                dw       offset decode_rm_reg
                dw       offset mnemonic_sbb
                dw       offset decode_rm_reg
                dw       offset mnemonic_sbb
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_sbb
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_sbb
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_sbb
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_push
                dw       offset decode_seg_reg
                dw       offset mnemonic_pop
                dw       offset decode_seg_reg
                dw       offset mnemonic_and
                dw       offset decode_rm_reg
                dw       offset mnemonic_and
                dw       offset decode_rm_reg
                dw       offset mnemonic_and
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_and
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_and
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_and
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_seg
                dw       offset decode_seg_override
                dw       offset mnemonic_daa
                dw       offset return_op
                dw       offset mnemonic_sub
                dw       offset decode_rm_reg
                dw       offset mnemonic_sub
                dw       offset decode_rm_reg
                dw       offset mnemonic_sub
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_sub
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_sub
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_sub
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_seg
                dw       offset decode_seg_override
                dw       offset mnemonic_das
                dw       offset return_op
                dw       offset mnemonic_xor
                dw       offset decode_rm_reg
                dw       offset mnemonic_xor
                dw       offset decode_rm_reg
                dw       offset mnemonic_xor
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_xor
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_xor
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_xor
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_seg
                dw       offset decode_seg_override
                dw       offset mnemonic_aaa
                dw       offset return_op
                dw       offset mnemonic_cmp
                dw       offset decode_rm_reg
                dw       offset mnemonic_cmp
                dw       offset decode_rm_reg
                dw       offset mnemonic_cmp
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_cmp
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_cmp
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_cmp
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_seg
                dw       offset decode_seg_override
                dw       offset mnemonic_aas
                dw       offset return_op
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_inc
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_dec
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_push
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_pop
                dw       offset decode_word_reg
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_jo
                dw       offset decode_short_rel
                dw       offset mnemonic_jno
                dw       offset decode_short_rel
                dw       offset mnemonic_jc
                dw       offset decode_short_rel
                dw       offset mnemonic_jnc
                dw       offset decode_short_rel
                dw       offset mnemonic_jz
                dw       offset decode_short_rel
                dw       offset mnemonic_jnz
                dw       offset decode_short_rel
                dw       offset mnemonic_jbe
                dw       offset decode_short_rel
                dw       offset mnemonic_ja
                dw       offset decode_short_rel
                dw       offset mnemonic_js
                dw       offset decode_short_rel
                dw       offset mnemonic_jns
                dw       offset decode_short_rel
                dw       offset mnemonic_jpe
                dw       offset decode_short_rel
                dw       offset mnemonic_jpo
                dw       offset decode_short_rel
                dw       offset mnemonic_jl
                dw       offset decode_short_rel
                dw       offset mnemonic_jge
                dw       offset decode_short_rel
                dw       offset mnemonic_jle
                dw       offset decode_short_rel
                dw       offset mnemonic_jg
                dw       offset decode_short_rel
                dw       terminate_psp
                dw       offset decode_group1_imm
                dw       terminate_psp
                dw       offset decode_group1_imm
                dw       terminate_psp
                dw       offset decode_group1_imm
                dw       terminate_psp
                dw       offset decode_group1_signed
                dw       offset mnemonic_test
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_test
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_xchg
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_xchg
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_mov
                dw       offset decode_rm_reg
                dw       offset mnemonic_mov
                dw       offset decode_rm_reg
                dw       offset mnemonic_mov
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_mov
                dw       offset decode_reg_rm_fields
                dw       offset mnemonic_mov
                dw       offset decode_rm_seg
                dw       offset mnemonic_lea
                dw       offset decode_reg_rm
                dw       offset mnemonic_mov
                dw       offset decode_seg_rm
                dw       offset mnemonic_pop
                dw       offset decode_rm_op
                dw       offset mnemonic_nop
                dw       offset return_op
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_xchg
                dw       offset decode_accumulator_exchange
                dw       offset mnemonic_cbw
                dw       offset return_op
                dw       offset mnemonic_cwd
                dw       offset return_op
                dw       offset mnemonic_call
                dw       offset append_far_pointer
                dw       offset mnemonic_wait
                dw       offset return_op
                dw       offset mnemonic_pushf
                dw       offset return_op
                dw       offset mnemonic_popf
                dw       offset return_op
                dw       offset mnemonic_sahf
                dw       offset return_op
                dw       offset mnemonic_lahf
                dw       offset return_op
                dw       offset mnemonic_mov
                dw       offset decode_accumulator_memory
                dw       offset mnemonic_mov
                dw       offset decode_accumulator_memory
                dw       offset mnemonic_mov
                dw       offset decode_memory_accumulator
                dw       offset mnemonic_mov
                dw       offset decode_memory_accumulator
                dw       offset mnemonic_movsb
                dw       offset return_op
                dw       offset mnemonic_movsw
                dw       offset return_op
                dw       offset mnemonic_cmpsb
                dw       offset return_op
                dw       offset mnemonic_cmpsw
                dw       offset return_op
                dw       offset mnemonic_test
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_test
                dw       offset decode_accumulator_imm
                dw       offset mnemonic_stosb
                dw       offset return_op
                dw       offset mnemonic_stosw
                dw       offset return_op
                dw       offset mnemonic_lodsb
                dw       offset return_op
                dw       offset mnemonic_lodsw
                dw       offset return_op
                dw       offset mnemonic_scasb
                dw       offset return_op
                dw       offset mnemonic_scasw
                dw       offset return_op
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_byte_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_mov
                dw       offset decode_word_reg_imm
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_ret
                dw       offset append_word_imm
                dw       offset mnemonic_ret
                dw       offset return_op
                dw       offset mnemonic_les
                dw       offset decode_reg_rm
                dw       offset mnemonic_lds
                dw       offset decode_reg_rm
                dw       offset mnemonic_mov
                dw       offset decode_modrm_imm
                dw       offset mnemonic_mov
                dw       offset decode_modrm_imm
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_ret
                dw       offset decode_far_return
                dw       offset mnemonic_ret
                dw       offset decode_long_return
                dw       offset mnemonic_int
                dw       offset decode_int3
                dw       offset mnemonic_int
                dw       offset append_byte_imm
                dw       offset mnemonic_into
                dw       offset return_op
                dw       offset mnemonic_iret
                dw       offset return_op
                dw       terminate_psp
                dw       offset decode_group2
                dw       terminate_psp
                dw       offset decode_group2
                dw       terminate_psp
                dw       offset decode_shift_count
                dw       terminate_psp
                dw       offset decode_shift_count
                dw       offset mnemonic_aam
                dw       offset decode_aam_aad_base
                dw       offset mnemonic_aad
                dw       offset decode_aam_aad_base
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_xlat
                dw       offset return_op
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_esc
                dw       offset decode_escape
                dw       offset mnemonic_loopnz
                dw       offset decode_short_rel
                dw       offset mnemonic_loopz
                dw       offset decode_short_rel
                dw       offset mnemonic_loop
                dw       offset decode_short_rel
                dw       offset mnemonic_jcxz
                dw       offset decode_short_rel
                dw       offset mnemonic_inb
                dw       offset append_byte_imm
                dw       offset mnemonic_inw
                dw       offset append_byte_imm
                dw       offset mnemonic_outb
                dw       offset append_byte_imm
                dw       offset mnemonic_outw
                dw       offset append_byte_imm
                dw       offset mnemonic_call
                dw       offset decode_near_rel
                dw       offset mnemonic_jmp
                dw       offset decode_near_rel
                dw       offset mnemonic_jmp
                dw       offset append_far_pointer
                dw       offset mnemonic_jmps
                dw       offset decode_short_rel
                dw       offset mnemonic_inb
                dw       offset decode_dx_port
                dw       offset mnemonic_inw
                dw       offset decode_dx_port
                dw       offset mnemonic_outb
                dw       offset decode_dx_port
                dw       offset mnemonic_outw
                dw       offset decode_dx_port
                dw       offset mnemonic_lock
                dw       offset finish_prefix_output
                dw       offset mnemonic_db
                dw       offset append_hex_byte
                dw       offset mnemonic_repnz
                dw       offset finish_prefix_output
                dw       offset mnemonic_repz
                dw       offset finish_prefix_output
                dw       offset mnemonic_hlt
                dw       offset return_op
                dw       offset mnemonic_cmc
                dw       offset return_op
                dw       terminate_psp
                dw       offset decode_group3
                dw       terminate_psp
                dw       offset decode_group3
                dw       offset mnemonic_clc
                dw       offset return_op
                dw       offset mnemonic_stc
                dw       offset return_op
                dw       offset mnemonic_cli
                dw       offset return_op
                dw       offset mnemonic_sti
                dw       offset return_op
                dw       offset mnemonic_cld
                dw       offset return_op
                dw       offset mnemonic_std
                dw       offset return_op
                dw       terminate_psp
                dw       offset decode_group45
                dw       terminate_psp
                dw       offset decode_group45

; High-bit-terminated mnemonic strings. Pointer aliases may select a suffix.

mnemonic_db                         label byte
                db       "D",0C2h

mnemonic_add                        label byte
                db       "AD",0C4h

mnemonic_adc                        label byte
                db       "AD",0C3h

mnemonic_sub                        label byte
                db       "SU",0C2h

mnemonic_sbb                        label byte
                db       "SB",0C2h

mnemonic_xor                        label byte
                db       "XO",0D2h

mnemonic_or                         label byte
                db       "O",0D2h

mnemonic_and                        label byte
                db       "AN",0C4h

mnemonic_cmp                        label byte
                db       "CM",0D0h

mnemonic_mov                        label byte
                db       "MO",0D6h

mnemonic_aaa                        label byte
                db       "AA",0C1h

mnemonic_aad                        label byte
                db       "AA",0C4h

mnemonic_aam                        label byte
                db       "AA",0CDh

mnemonic_aas                        label byte
                db       "AA",0D3h

mnemonic_call                       label byte
                db       "CAL",0CCh

mnemonic_cbw                        label byte
                db       "CB",0D7h

mnemonic_clc                        label byte
                db       "CL",0C3h

mnemonic_cld                        label byte
                db       "CL",0C4h

mnemonic_cli                        label byte
                db       "CL",0C9h

mnemonic_cmc                        label byte
                db       "CM",0C3h

mnemonic_cmpsb                      label byte
                db       "CMPS",0C2h

mnemonic_cmpsw                      label byte
                db       "CMPS",0D7h

mnemonic_cwd                        label byte
                db       "CW",0C4h

mnemonic_daa                        label byte
                db       "DA",0C1h

mnemonic_das                        label byte
                db       "DA",0D3h

mnemonic_dec                        label byte
                db       "DE",0C3h

mnemonic_div                        label byte
                db       "DI",0D6h

mnemonic_esc                        label byte
                db       "ES",0C3h

mnemonic_hlt                        label byte
                db       "HL",0D4h

mnemonic_idiv                       label byte
                db       "IDI",0D6h

mnemonic_imul                       label byte
                db       "IMU",0CCh

mnemonic_inb                        label byte
                db       "IN",0C2h

mnemonic_inw                        label byte
                db       "IN",0D7h

mnemonic_inc                        label byte
                db       "IN",0C3h

mnemonic_int                        label byte
                db       "IN",0D4h

mnemonic_into                       label byte
                db       "INT",0CFh

mnemonic_iret                       label byte
                db       "IRE",0D4h

mnemonic_ja                         label byte
                db       "J",0C1h

mnemonic_jnc                        label byte
                db       "JN",0C3h

mnemonic_jc                         label byte
                db       "J",0C3h

mnemonic_jbe                        label byte
                db       "JB",0C5h

mnemonic_jcxz                       label byte
                db       "JCX",0DAh

mnemonic_jz                         label byte
                db       "J",0DAh

mnemonic_jg                         label byte
                db       "J",0C7h

mnemonic_jge                        label byte
                db       "JG",0C5h

mnemonic_jl                         label byte
                db       "J",0CCh

mnemonic_jle                        label byte
                db       "JL",0C5h

mnemonic_jmp                        label byte
                db       "JM",0D0h

mnemonic_jnz                        label byte
                db       "JN",0DAh

mnemonic_jpe                        label byte
                db       "JP",0C5h

mnemonic_jpo                        label byte
                db       "JP",0CFh

mnemonic_jmps                       label byte
                db       "JMP",0D3h

mnemonic_jns                        label byte
                db       "JN",0D3h

mnemonic_jno                        label byte
                db       "JN",0CFh

mnemonic_jo                         label byte
                db       "J",0CFh

mnemonic_js                         label byte
                db       "J",0D3h

mnemonic_lahf                       label byte
                db       "LAH",0C6h

mnemonic_lds                        label byte
                db       "LD",0D3h

mnemonic_lea                        label byte
                db       "LE",0C1h

mnemonic_les                        label byte
                db       "LE",0D3h

mnemonic_lock                       label byte
                db       "LOC",0CBh

mnemonic_lodsb                      label byte
                db       "LODS",0C2h

mnemonic_lodsw                      label byte
                db       "LODS",0D7h

mnemonic_loop                       label byte
                db       "LOO",0D0h

mnemonic_loopz                      label byte
                db       "LOOP",0DAh

mnemonic_loopnz                     label byte
                db       "LOOPN",0DAh

mnemonic_movsb                      label byte
                db       "MOVS",0C2h

mnemonic_movsw                      label byte
                db       "MOVS",0D7h

mnemonic_mul                        label byte
                db       "MU",0CCh

mnemonic_neg                        label byte
                db       "NE",0C7h

mnemonic_nop                        label byte
                db       "NO",0D0h

mnemonic_not                        label byte
                db       "NO",0D4h

mnemonic_outb                       label byte
                db       "OUT",0C2h

mnemonic_outw                       label byte
                db       "OUT",0D7h

mnemonic_pop                        label byte
                db       "PO",0D0h

mnemonic_popf                       label byte
                db       "POP",0C6h

mnemonic_push                       label byte
                db       "PUS",0C8h

mnemonic_pushf                      label byte
                db       "PUSH",0C6h

mnemonic_rcl                        label byte
                db       "RC",0CCh

mnemonic_rcr                        label byte
                db       "RC",0D2h

mnemonic_repz                       label byte
                db       "REP",0DAh

mnemonic_repnz                      label byte
                db       "REPN",0DAh

mnemonic_ret                        label byte
                db       "RE",0D4h

mnemonic_rol                        label byte
                db       "RO",0CCh

mnemonic_ror                        label byte
                db       "RO",0D2h

mnemonic_sahf                       label byte
                db       "SAH",0C6h

mnemonic_sar                        label byte
                db       "SA",0D2h

mnemonic_scasb                      label byte
                db       "SCAS",0C2h

mnemonic_scasw                      label byte
                db       "SCAS",0D7h

mnemonic_shl                        label byte
                db       "SH",0CCh

mnemonic_shr                        label byte
                db       "SH",0D2h

mnemonic_stc                        label byte
                db       "ST",0C3h

mnemonic_std                        label byte
                db       "ST",0C4h

mnemonic_sti                        label byte
                db       "ST",0C9h

mnemonic_stosb                      label byte
                db       "STOS",0C2h

mnemonic_stosw                      label byte
                db       "STOS",0D7h

mnemonic_test                       label byte
                db       "TES",0D4h

mnemonic_wait                       label byte
                db       "WAI",0D4h

mnemonic_xchg                       label byte
                db       "XCH",0C7h

mnemonic_xlat                       label byte
                db       "XLA",0D4h

mnemonic_seg                        label byte
                db       "SE",0C7h

mnemonic_invalid                    label byte
                db       "??",0BFh

; Grouped opcode mnemonic pointers, selected by the ModR/M reg field.

shift_mnemonics                     label word
                dw       offset mnemonic_rol
                dw       offset mnemonic_ror
                dw       offset mnemonic_rcl
                dw       offset mnemonic_rcr
                dw       offset mnemonic_shl
                dw       offset mnemonic_shr
                dw       offset mnemonic_invalid
                dw       offset mnemonic_sar

arithmetic_mnemonics                label word
                dw       offset mnemonic_add
                dw       offset mnemonic_or
                dw       offset mnemonic_adc
                dw       offset mnemonic_sbb
                dw       offset mnemonic_and
                dw       offset mnemonic_sub
                dw       offset mnemonic_xor
                dw       offset mnemonic_cmp

unary_mnemonics                     label word
                dw       offset mnemonic_test
                dw       offset mnemonic_invalid
                dw       offset mnemonic_not
                dw       offset mnemonic_neg
                dw       offset mnemonic_mul
                dw       offset mnemonic_imul
                dw       offset mnemonic_div
                dw       offset mnemonic_idiv

group45_mnemonics                   label word
                dw       offset mnemonic_inc
                dw       offset mnemonic_dec
                dw       offset mnemonic_call
                dw       offset mnemonic_call
                dw       offset mnemonic_jmp
                dw       offset mnemonic_jmp
                dw       offset mnemonic_push
                dw       offset mnemonic_invalid

; Pointers to saved ES, CS, SS, DS words, in segment-register encoding order.

seg_reg_pointers                    label word
                dw       offset saved_es
                dw       offset saved_cs
                dw       offset saved_ss
                dw       offset saved_ds

; Names in saved-register order; PC aliases IP in the R command lookup.

reg_names                           label byte
                db       "AXBXCXDXSPBPSIDIDSESSSCSIPPC"

; Sixteen flag-name pairs in bit order from bit 15 down to bit 0; zero pairs are hidden.

flag_set_names                      label byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,"OVDN"
                db       "EI",0h,0h,"NGZR",0h,0h,"AC",0h,0h,"PE",0h,0h,"CY"

; Names for the clear state of the corresponding flags.

flag_clear_names                    label byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,"NVUP"
                db       "DI",0h,0h,"PLNZ",0h,0h,"NA",0h,0h,"PO",0h,0h,"NC"

terminated_message                  label byte
                db       0Dh,0Ah,"Program te"
                db       "rminated normally"

break_message                       label byte
                db       0Dh,0Ah,"$"

invalid_drive_message               label byte
                db       "Invalid drive specification",0Dh,0Ah,"$"

file_not_found_message              label byte
                db       "File not found",0Dh,0Ah,"$"

directory_full_message              label byte
                db       "No room in disk directory",0Dh,0Ah,"$"

disk_full_message                   label byte
                db       "Insufficient space on disk",0Dh,0Ah,"$"

disk_error_word                     label byte
                db       "Disk$"

write_protect_word                  label byte
                db       "Write protect$"

disk_error_context                  label byte
                db       " error "

disk_error_verb                     label byte
                db       "reading drive "

disk_error_drive                    label byte
                db       "A",0Dh,0Ah,"$"

read_verb                           label byte
                db       "read"

write_verb                          label byte
                db       "writ"

memory_error_message                label byte
                db       "Insufficient memory",0Dh,0Ah,"$"

syntax_error_message                label byte
                db       "^"

reg_error_suffix                    label byte
                db       " Error",0Dh,8Ah

erase_char_text                     label byte
                db       " ",88h

bad_exe_message                     label byte
                db       "Error in EXE/HEX file",0Dh,0Ah,"$"

cannot_write_exe_message            label byte
                db       "EXE/HEX file cannot be written",0Dh,0Ah,"$"

writing_message                     label byte
                db       "Writing $"

bytes_message                       label byte
                db       " bytes",0Dh,0Ah,"$"

; DEBUG command stack grows down from saved_ax. Preserve initialized zero storage.

debug_stack                         label byte
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

; Target register image: AX BX CX DX SP BP SI DI DS ES SS CS IP FLAGS.

saved_ax                            label word
                db       0h

saved_ah                            label byte
                db       0h

saved_bx                            label word
                dw       0h

saved_cx                            label word
                dw       0h

saved_dx                            label word
                dw       0h

saved_sp                            label word
                dw       5Ah

saved_bp                            label word
                dw       0h

saved_si                            label word
                dw       0h

saved_di                            label word
                dw       0h

saved_ds                            label word
                dw       0h

saved_es                            label word
                dw       0h

saved_ss                            label word
                dw       0h

saved_cs                            label word
                dw       0h

saved_ip                            label word
                dw       100h

saved_flags                         label word
                db       0h

saved_flags_high                    label byte
                db       0h

file_transfer_function              label byte
                db       27h

regs_remaining                      label byte
                db       0Dh

dump_line_mask                      label byte
                db       0Fh

regs_per_row                        label byte
                db       8h

def_dump_count                      label word
                dw       80h

; DOS buffered input header; command text continues into uninitialized workspace.

console_input_max                   label byte
                db       50h

console_input_length                label byte
                db       1h

console_input_text                  label byte
                db       0Dh

program ends
end start
