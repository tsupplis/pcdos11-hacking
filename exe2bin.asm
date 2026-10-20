; *-------------------------------------------------------------------------
; EXE2BIN.ASM - PC DOS 1.10 EXE-to-binary conversion utility
;
; Original: reference/exe2bin.exe, 1280 bytes.
; Build: make exe2bin.exe     Verify: make check-exe2bin
;
; This source emits the complete MZ file as a flat container. The intermediate
; EXBIMAGE executable is only a vehicle for MASM/LINK; EXE2BIN extracts its
; unrelocated bytes to produce the reconstructed EXE2BIN.EXE.
;
; File offsets 0200h..03C9h contain code with loaded CS offsets 0000h..01C9h.
; DS is loaded as CS+001Ch; DS offset 000Ah starts the first message.
; The data frame overlaps the final ten code bytes within that paragraph.
; Header size declares 1228 bytes; 52 final zero bytes are retained as overlay.
; All MZ header words, both relocation entries and padding are explicit.
; Byte identity is verified; DOS execution behavior needs separate testing.
; *-------------------------------------------------------------------------

program         segment
                assume cs:program
                org 0
file_start:

jmpn            macro target
                db 0E9h
                dw target - $ - 2
                endm

return_to_psp macro
                db 0CBh
                endm

; MZ container header. Values are those stored on disk, before DOS relocation.
mz_signature label word
                dw       5A4Dh
mz_last_page_bytes label word
                dw       0CCh
mz_pages label word
                dw       3h
mz_relocation_count label word
                dw       2h
mz_header_paragraphs label word
                dw       20h
mz_minimum_extra label word
                dw       0h
mz_maximum_extra label word
                dw       0FFFFh
mz_initial_ss label word
                dw       2Dh
mz_initial_sp label word
                dw       80h
mz_checksum label word
                dw       4274h
mz_initial_ip label word
                dw       0h
mz_initial_cs label word
                dw       0h
mz_relocation_table label word
                dw       1Ch
mz_overlay_number label word
                dw       0h

data_segment_relocation label word
                dw       data_segment_fixup - load_image
                dw       0

image_segment_relocation label word
                dw       image_segment_fixup - load_image
                dw       0

mz_header_padding label byte
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0,0,0,0,0
                db       0,0,0,0,0,0,0,0

load_image label byte
; DS frame is a paragraph within the loaded code/data image.
data_frame equ load_image + 1C0h
psp_end_segment equ 2
psp_command_tail equ 81h

; DS initially addresses the PSP. Save a far return to PSP:0 for termination.

start:
                mov      si,psp_command_tail
                mov      di,9Bh
                push     ds
                xor      ax,ax
                push     ax
                mov      bx,ds:[psp_end_segment]
data_segment_fixup equ $ + 1
                mov      dx,(data_frame - load_image) / 16
                mov      es,dx

; DOS AH=29h parses the input name, preserving its default EXE extension.
                mov      ax,2909h
                int      21h
                push     si
                push     ds
                mov      si,9Bh
                mov      di,0C0h
                mov      ds,dx
                mov      cx,9
                rep      movsb
                pop      ds
                pop      si

; Parse the optional output name, retaining the input name and default BIN extension.
                mov      di,0C0h
                mov      ax,290Fh
                int      21h
                mov      ds,dx
                mov      ah,0Fh
                mov      dx,9Bh
                int      21h
                or       al,al
                je       read_input_header
                mov      dx,0Ah

print_error_and_exit:
                mov      ah,9
                int      21h
                return_to_psp 

insufficient_memory:
                mov      dx,19h
                jmp      short print_error_and_exit

cannot_convert:
                mov      dx,82h

reject_with_message:
                jmp      short print_error_and_exit

; Read the first 26 header bytes using FCB random-block input with one-byte records.

read_input_header:
                mov      dx,0ECh
                mov      ah,1Ah
                int      21h
                mov      word ptr ds:[input_record_size - data_frame],1
                mov      cx,1Ah
                mov      dx,9Bh
                mov      ah,27h
                int      21h
                cmp      word ptr ds:[header_buffer - data_frame],5A4Dh
                jne      cannot_convert

; Round the MZ header to a 512-byte boundary and seek past it.
                mov      ax,ds:[header_paragraphs - data_frame]
                add      ax,1Fh
                cmp      ax,1000h
                jae      insufficient_memory
                and      ax,0FFE0h
                mov      cl,4
                shl      ax,cl
                mov      word ptr ds:[input_random_record - data_frame],ax
                xchg     al,ah
                shr      ax,1

; Convert file pages and final-page bytes to the load-image byte count.
                mov      dx,ds:[header_pages_or_length - data_frame]
                sub      dx,ax
                cmp      dx,80h
                jae      insufficient_memory
                xchg     dh,dl
                shl      dx,1
                mov      ax,ds:[header_last_page_bytes - data_frame]
                or       ax,ax
                je       save_binary_length

test_last_page_bytes:
                cmp      ax,4
                je       save_binary_length
                sub      dx,200h
                add      dx,ax

save_binary_length:
                mov      word ptr ds:[header_pages_or_length - data_frame],dx
                add      dx,0Fh
                shr      dx,cl

; The two loader relocations add the actual program load segment to these constants.
image_segment_fixup equ $ + 1
                mov      bp,35h
                add      dx,bp
                cmp      dx,bx
                ja       insufficient_memory

; Require zero SS, SP and CS. Accept IP=0, or IP=100h only without relocations.
                mov      dx,82h
                mov      ax,ds:[header_initial_ss - data_frame]
                or       ax,ds:[header_initial_sp - data_frame]
                or       ax,ds:[header_initial_cs - data_frame]

reject_header:
                jne      reject_with_message
                mov      ax,ds:[header_initial_ip - data_frame]
                or       ax,ax
                je       check_relocations
                cmp      ax,100h
                jne      reject_header
                inc      byte ptr ds:[input_random_record_high - data_frame]
                sub      ds:[header_pages_or_length - data_frame],ax
                cmp      word ptr ds:[header_relocations - data_frame],0
                jne      reject_header

; Relocated images need a user-supplied hexadecimal segment base.

check_relocations:
                xor      bx,bx
                cmp      word ptr ds:[header_relocations - data_frame],0
                je       read_load_image

prompt_relocation_base:
                mov      dx,59h
                mov      ah,9
                int      21h
                mov      ah,0Ah
                mov      dx,0E5h
                int      21h
                mov      dx,7Fh
                mov      ah,9
                int      21h
                mov      si,0E7h

; MOV preserves ZF from console output; retry on an empty buffered input line.

clear_base_input_length:
                mov      byte ptr ds:[si-1],0
                je       prompt_relocation_base

; Accept decimal or uppercase/lowercase hexadecimal digits until the final CR.

parse_hex_digit:
                lodsb    
                sub      al,30h
                jb       check_base_terminator
                cmp      al,0Ah
                jb       accumulate_hex_digit
                and      al,5Fh
                sub      al,7
                cmp      al,0Ah
                jb       check_base_terminator
                cmp      al,10h
                jae      check_base_terminator

accumulate_hex_digit:
                shl      bx,1
                shl      bx,1
                shl      bx,1
                shl      bx,1
                or       bl,al
                jmp      short parse_hex_digit

check_base_terminator:
                cmp      byte ptr ds:[si-1],0Dh
                jne      prompt_relocation_base

; BX becomes the image-buffer segment; BP retains the requested relocation base.

read_load_image:
                xchg     bx,bp
                push     ds
                mov      ds,bx
                xor      dx,dx
                mov      ah,1Ah
                int      21h
                pop      ds
                mov      cx,ds:[header_pages_or_length - data_frame]
                mov      dx,9Bh
                mov      ah,27h
                int      21h
                or       al,al
                je       check_fixups
                jmpn     cannot_convert

; For each relocation, reread its offset/segment pair from the input file.

check_fixups:
                cmp      word ptr ds:[header_relocations - data_frame],0
                je       create_binary_output
                mov      ax,ds:[header_relocation_offset - data_frame]
                mov      word ptr ds:[input_random_record - data_frame],ax
                mov      dx,0ECh
                mov      ah,1Ah
                int      21h

read_relocation_entry:
                mov      ah,27h
                mov      dx,9Bh
                mov      cx,4
                int      21h
                or       al,al
                je       apply_segment_fixup
                jmpn     cannot_convert

; ES:DI selects the relocated image word; add the requested base segment.

apply_segment_fixup:
                mov      di,ds:[header_buffer - data_frame]
                mov      ax,ds:[header_last_page_bytes - data_frame]
                add      ax,bx
                mov      es,ax
                add      word ptr es:[di],bp
                dec      word ptr ds:[header_relocations - data_frame]
                jne      read_relocation_entry

; Create the BIN output and write the load image with one-byte FCB records.

create_binary_output:
                mov      ah,16h
                mov      dx,0C0h
                int      21h
                or       al,al
                jne      create_failed
                push     ds
                mov      ds,bx
                xor      dx,dx
                mov      ah,1Ah
                int      21h
                pop      ds
                mov      word ptr ds:[output_record_size - data_frame],1
                mov      cx,ds:[header_pages_or_length - data_frame]
                mov      dx,0C0h
                mov      ah,28h
                int      21h
                or       al,al
                jne      disk_full

; Close output and far-return through the saved PSP termination address.
                mov      ah,10h
                mov      dx,0C0h
                int      21h
                return_to_psp 

disk_full:
                mov      dx,41h
                jmpn     print_error_and_exit

create_failed:
                mov      dx,2Dh
                jmpn     print_error_and_exit

file_not_found_text label byte
                db       "File not found$"

no_memory_text label byte
                db       "Insufficient memory$"

create_error_text label byte
                db       "File creation error$"

disk_full_text label byte
                db       "Insufficient disk space$"

fixup_prompt label byte
                db       "Fix-ups needed - base segment (hex): $"

crlf_text label byte
                db       0Dh,0Ah,"$"

cannot_convert_text label byte
                db       "File cannot be converted$"

input_fcb label byte
                db       0h,"        EXE"
                db       0h,0h

input_record_size label word
                dw       0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h

input_random_record label byte
                db       0h

input_random_record_high label byte
                db       0h,0h,0h

output_fcb label byte
                db       0h,"        BIN"
                db       0h,0h

output_record_size label word
                dw       0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h

base_input_max label byte
                db       5h

base_input_length label byte
                db       0h

base_input_text label byte
                db       0h,0h,0h,0h,0h

header_buffer label word
                dw       0h

header_last_page_bytes label word
                dw       0h

header_pages_or_length label word
                dw       0h

header_relocations label word
                dw       0h

header_paragraphs label word
                dw       0h
                db       0h,0h,0h,0h

header_initial_ss label word
                dw       0h

header_initial_sp label word
                dw       0h
                db       0h,0h

header_initial_ip label word
                dw       0h

header_initial_cs label word
                dw       0h

header_relocation_offset label word
                dw       0h
                db       0h,0h,0h,0h,0h,0h

; Zero overlay beyond the length declared by mz_pages/mz_last_page_bytes.
preserved_overlay label byte
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db       0h,0h,0h,0h

program ends
end file_start
