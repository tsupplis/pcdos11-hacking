; *-------------------------------------------------------------------------
; FORMAT.ASM - shared IBM/Microsoft diskette formatter
;
; Build: make ibmfmt.com msfmt.com     Verify: make check-utilities
; Originals: reference/format.com and reference/msformat.com, 3816 bytes each.
; Included by ibmfmt.asm / msfmt.asm; MSVER selects the system filenames.
; Comments describe intent and register/state contracts.
; Exact addresses and bytes are kept in mappings/ and verified on rebuild.
; Reassembly is exact; runtime testing is a separate verification step.
;
; Layout:
; 0100h-06F4h  code
; 09F2h-0C45h  code
; All remaining image bytes are initialized data, messages, or tables.
; Code at 09F2h starts the IBM floppy hardware implementation.
; -------------------------------------------------------------------------

program         segment
                assume  cs:program, ds:program
                org     100h

; Preserve near jumps even when the target is in short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

; Literal boot far transfer and CS-prefixed string fetch.
jmp_far                 macro   segval, offval
                db      0EAh
                dw      offval, segval
                endm

lodsb_cs                macro
                db      2Eh,0ACh
                endm

; Command switches retained for each formatted disk.
option_transfer_system   equ     1
option_single_side       equ     2

; PSP fields and fixed data addresses (equates do not emit bytes).
drive_arg_seen           equ     phase_flag      ; Command parsing phase.
space_counted            equ     phase_flag      ; Per-disk formatting phase.

; External memory fields and resident patch locations; image data is labeled
; below.
psp_end_segment          equ     2h
dos_last_diskette        equ     4h
default_fcb_drive        equ     5Ch
command_length           equ     80h
command_tail             equ     81h

; ------------------------------------------------------------------------
; Code and initialized data in original file order
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; Validate the selected drive and command switches; use the stack ending at
; 09F0h.
; ------------------------------------------------------------------------

start:
                mov     sp,offset stack_top
                cmp     al,0FFh
                jnz     select_format_drive
                mov     dx,offset msg_invalid_drive
                call    print_string
                jmpn    terminate

select_format_drive:
                mov     ah,19h
                int     21h
                mov     ds:[original_drive],al
                mov     si,5Ch
                lodsb
                or      al,al
                jnz     save_format_drive
                mov     al,ds:[original_drive]
                inc     al

save_format_drive:
                dec     al
                mov     ds:[default_fcb_drive],al
                mov     ds:[target_drive],al
                xor     bx,bx
                mov     si,81h

; Accept one drive operand and supported switches only; /S requests system
; transfer and /1 one side.
parse_next_argument:
                call    skip_spaces
                lodsb
                cmp     al,2Fh
                jz      parse_format_switch
                cmp     al,0Dh
                jz      options_ready
                lodsb
                cmp     al,3Ah
                jnz     invalid_parameter_exit
                cmp     byte ptr ds:[drive_arg_seen],0h
                jnz     invalid_parameter_exit
                inc     byte ptr ds:[drive_arg_seen]
                jmp     short parse_next_argument

parse_format_switch:
                lodsb
                cmp     al,41h
                jl      find_supported_switch
                and     al,0DFh

find_supported_switch:
                mov     cl,ds:[option_count]
                or      cl,cl
                jz      invalid_parameter_exit
                mov     ch,0h
                mov     di,offset option_chars
                repne   scasb
                jnz     invalid_parameter_exit
                mov     ax,1h
                shl     ax,cl
                or      bx,ax
                jmp     short parse_next_argument

invalid_parameter_exit:
                mov     dx,offset msg_invalid_parameter
                call    print_string
                jmpn    terminate

; ------------------------------------------------------------------------
; Advance DS:SI over spaces and tabs; leave SI on the first other character.
; ------------------------------------------------------------------------

skip_spaces:
                lodsb
                cmp     al,20h
                jz      skip_spaces
                cmp     al,9h
                jz      skip_spaces
                dec     si
                ret

; ------------------------------------------------------------------------
; Save the parsed /S and /1 flags and prepare optional system-file transfer.
; ------------------------------------------------------------------------

; Read system files before asking for a blank disk, so one-drive formatting
; can swap source and target.
options_ready:
                mov     word ptr ds:[format_options],bx
                test    word ptr ds:[format_options],option_transfer_system
                jz      finish_hardware_setup

load_dos_disk_files:
                call    open_system_files
                jnc     load_command_interpreter

request_dos_disk_again:
                call    prompt_dos_disk
                jmp     short load_dos_disk_files

load_command_interpreter:
                call    read_command_file
                jc      request_dos_disk_again

finish_hardware_setup:
                call    hardware_finish
                jnc     save_format_options
                mov     dx,offset msg_fatal_format_error
                call    print_string
                jmpn    terminate

save_format_options:
                mov     dx,word ptr ds:[format_options]
                mov     word ptr ds:[saved_options],dx

; ------------------------------------------------------------------------
; Initialize counters, prompt for a diskette, and start the format pass.
; ------------------------------------------------------------------------

; The byte used to detect duplicate drive operands now tracks whether system
; space was counted.
format_another:
                mov     word ptr ds:[bad_bytes_low],0h
                mov     word ptr ds:[bad_bytes_high],0h
                mov     word ptr ds:[system_bytes],0h
                mov     byte ptr ds:[space_counted],0h
                mov     byte ptr ds:[fat_initialized],0h
                mov     dx,word ptr ds:[saved_options]
                mov     word ptr ds:[format_options],dx
                mov     al,ds:[target_drive]
                add     al,41h
                mov     ds:[target_prompt_drive],al
                mov     dx,offset msg_insert_blank_disk
                call    print_string
                mov     dx,offset msg_press_key
                call    print_string
                call    wait_key
                call    print_line_end
                call    print_line_end
                call    hardware_initialize
                jnc     format_tracks_loop

format_failed_restart:
                mov     dx,offset msg_format_failure
                call    print_string
                jmp     short format_another

; ------------------------------------------------------------------------
; Consume hardware formatter results; mark bad clusters and account for disk
; space.
; ------------------------------------------------------------------------

; The hardware layer returns a bad range as BX=first sector, AX=count; AX=0
; means formatting is finished.
format_tracks_loop:
                call    format_next_tracks
                jc      format_failed_restart
                cmp     ax,0h
                jnz     check_bad_reserved_sectors
                jmpn    finish_formatted_disk

; Damage in the reserved boot/FAT/root region makes the disk unusable, even
; without /S.
check_bad_reserved_sectors:
                cmp     bx,word ptr ds:[reserved_sectors]
                jnl     record_bad_sector_range
                mov     dx,offset msg_track_zero_bad
                call    print_string
                jmp     short format_failed_restart

record_bad_sector_range:
                mov     word ptr ds:[bad_sector_count],ax
                cmp     byte ptr ds:[fat_initialized],0h
                jnz     check_system_area_damage
                inc     byte ptr ds:[fat_initialized]
                push    bx
                call    initialize_fat
                pop     bx

check_system_area_damage:
                test    word ptr ds:[format_options],option_transfer_system
                jz      accumulate_bad_sector_bytes
                cmp     byte ptr ds:[space_counted],0h
                jnz     check_bad_system_sectors
                inc     byte ptr ds:[space_counted]
; Compute the system-file allocation boundary once per target disk.
                call    count_system_space
                xor     dx,dx
                mov     ax,word ptr ds:[system_bytes]
                div     word ptr ds:[bytes_per_sector]
                add     ax,word ptr ds:[reserved_sectors]
                mov     word ptr ds:[system_sector_limit],ax

; A damaged system-file area disables /S but still permits a usable data
; disk.
check_bad_system_sectors:
                cmp     bx,word ptr ds:[system_sector_limit]
                jg      accumulate_bad_sector_bytes
                mov     dx,offset msg_system_disk_unsuitable
                call    print_string
; Keep formatting as a data disk when the system area is damaged.
                and     word ptr ds:[format_options],0FFFEh
                mov     word ptr ds:[system_bytes],0h

accumulate_bad_sector_bytes:
                mov     ax,word ptr ds:[bad_sector_count]
                mul     word ptr ds:[bytes_per_sector]
                add     word ptr ds:[bad_bytes_low],ax
                jnc     count_bad_clusters
                inc     word ptr ds:[bad_bytes_high]

; Round the failed sector span to allocation units before writing FAT12 bad-
; cluster markers.
count_bad_clusters:
                mov     ax,word ptr ds:[bad_sector_count]
                div     word ptr ds:[sectors_per_cluster]
                or      dx,dx
                jz      locate_bad_cluster_range
                inc     ax

locate_bad_cluster_range:
                mov     cx,ax
                mov     ax,word ptr ds:[bad_sector_count]
                add     bx,ax
                sub     bx,word ptr ds:[reserved_sectors]
                xchg    ax,bx
                div     word ptr ds:[sectors_per_cluster]
                xchg    ax,bx

; Mark backwards from the last affected cluster so every part of the
; returned bad range is covered.
mark_bad_cluster:
                mov     dx,0FF7h
                call    set_fat12_entry
                dec     bx
                loop    mark_bad_cluster
                jmpn    format_tracks_loop

; ------------------------------------------------------------------------
; BX=cluster, DX=FAT12 value. Update packed FAT in the saved FAT
; segment/offset.
; ------------------------------------------------------------------------

; Odd clusters occupy the high twelve bits of a word; even clusters occupy
; the low twelve.
set_fat12_entry:
                push    es
                mov     es,word ptr ds:[fat_segment]
                push    bx
                push    dx
                mov     si,bx
                shr     bx,1
                add     bx,word ptr ds:[fat_offset]
                add     bx,si
                shr     si,1
                mov     si,es:[bx]
                jnc     preserve_next_fat_nibble
                shl     dx,1
                shl     dx,1
                shl     dx,1
                shl     dx,1
                and     si,0Fh
                jmp     short store_fat12_value

preserve_next_fat_nibble:
                and     si,0F000h

store_fat12_value:
                or      si,dx
                mov     es:[bx],si
                pop     dx
                pop     bx
                pop     es
                ret

finish_formatted_disk:
                cmp     byte ptr ds:[fat_initialized],0h
                jnz     flush_completed_fat
                call    initialize_fat
                call    count_system_space

; Set the DOS FAT dirty byte before reset flushes the updated allocation
; table to disk.
flush_completed_fat:
                push    es
                mov     ax,word ptr ds:[fat_segment]
                mov     es,ax
                mov     di,word ptr ds:[fat_offset]
                mov     byte ptr es:[di-1h],1h          ; Tell DOS that its in-memory FAT needs writing.
                pop     es
                test    word ptr ds:[format_options],option_transfer_system
                jz      finish_system_transfer
                call    write_system_files
                call    write_command_file
                mov     dx,offset msg_system_transferred
                call    print_string

finish_system_transfer:
                call    print_line_end
                mov     ah,0Dh
                int     21h
                call    hardware_finish
                jnc     report_disk_space
                jmpn    format_failed_restart

; The saved allocation count is converted into a 32-bit byte total only
; after formatting is complete.
report_disk_space:
                mov     ax,word ptr ds:[total_bytes_low]
                mul     word ptr ds:[bytes_per_sector]
                mov     cx,word ptr ds:[sectors_per_cluster]
                call    scale_cluster_bytes
                mov     word ptr ds:[total_bytes_low],ax
                mov     word ptr ds:[total_bytes_high],dx
                mov     si,ax
                mov     di,dx
                mov     bx,offset msg_total_bytes
                call    print_number
                cmp     word ptr ds:[system_bytes],0h
                jz      check_bad_space_report
                mov     si,word ptr ds:[system_bytes]
                xor     di,di
                mov     bx,offset msg_system_bytes
                call    print_number

check_bad_space_report:
                cmp     word ptr ds:[bad_bytes_low],0h
                jnz     print_bad_space
                cmp     word ptr ds:[bad_bytes_high],0h
                jz      print_available_space

print_bad_space:
                mov     si,word ptr ds:[bad_bytes_low]
                mov     di,word ptr ds:[bad_bytes_high]
                mov     bx,offset msg_bad_sector_bytes
                call    print_number

print_available_space:
                mov     cx,word ptr ds:[total_bytes_low]
                mov     bx,word ptr ds:[total_bytes_high]
                sub     cx,word ptr ds:[bad_bytes_low]
                sbb     bx,word ptr ds:[bad_bytes_high]
                sub     cx,word ptr ds:[system_bytes]
                sbb     bx,0h
                mov     si,cx
                mov     di,bx
                mov     bx,offset msg_available_bytes
                call    print_number
                call    ask_another
                jmpn    format_another

; ------------------------------------------------------------------------
; DI:SI=32-bit number, BX=message. Convert to packed BCD and display decimal
; bytes.
; ------------------------------------------------------------------------

print_number:
                push    bx
                xor     ax,ax
                mov     bx,ax
                mov     bp,ax
                mov     cx,20h

; Shift one input bit at a time into packed BCD words using decimal-adjusted
; doubling.
convert_binary_to_bcd:
                shl     si,1
                rcl     di,1
                xchg    ax,bp
                call    bcd_double
                xchg    ax,bp
                xchg    ax,bx
                call    bcd_double
                xchg    ax,bx
                adc     al,0h
                loop    convert_binary_to_bcd
                mov     cx,1810h
                xchg    ax,dx
                call    print_digit
                xchg    ax,bx
                call    print_bcd_word
                xchg    ax,bp
                call    print_bcd_word
                pop     dx
                cmp     dx,0h
                jz      print_number_ret
                call    print_string

print_number_ret:
                ret

; ------------------------------------------------------------------------
; Print packed BCD AX using the common byte and digit routines.
; ------------------------------------------------------------------------

print_bcd_word:
                push    ax
                mov     dl,ah
                call    print_bcd_byte
                pop     dx

; ------------------------------------------------------------------------
; Print packed BCD DL as two decimal digits.
; ------------------------------------------------------------------------

print_bcd_byte:
                mov     dh,dl
                shr     dl,1
                shr     dl,1
                shr     dl,1
                shr     dl,1
                call    print_digit
                mov     dl,dh

; ------------------------------------------------------------------------
; Print DL low nibble, tracking leading positions in CH/CL.
; ------------------------------------------------------------------------

print_digit:
                and     dl,0Fh
                jz      format_decimal_digit
                mov     cl,0h

format_decimal_digit:
                dec     ch
                and     cl,ch
                or      dl,30h
                sub     dl,cl
                mov     ah,2h
                int     21h
                ret

; ------------------------------------------------------------------------
; Double packed BCD AX with incoming carry using ADC/DAA.
; ------------------------------------------------------------------------

bcd_double:
                adc     al,al
                daa
                xchg    al,ah
                adc     al,al
                daa
                xchg    al,ah

bcd_or_scale_ret:
                ret

; ------------------------------------------------------------------------
; Shift DX:AX left according to the power of two in CX.
; ------------------------------------------------------------------------

scale_cluster_bytes:
                shr     cx,1
                jc      bcd_or_scale_ret
                shl     ax,1
                rcl     dx,1
                jmp     short scale_cluster_bytes

; ------------------------------------------------------------------------
; Accumulate rounded allocation sizes for the three system files.
; ------------------------------------------------------------------------

count_system_space:
                mov     ax,word ptr ds:[bios_file_bytes]
                call    round_file_allocation
                mov     ax,word ptr ds:[dos_file_bytes]
                call    round_file_allocation
                mov     ax,word ptr ds:[command_file_bytes]

; ------------------------------------------------------------------------
; AX=file bytes. Round to disk allocation units and add to system_bytes.
; ------------------------------------------------------------------------

round_file_allocation:
                xor     dx,dx
                div     word ptr ds:[bytes_per_sector]
                or      dx,dx
                jz      round_cluster_allocation
                inc     ax

round_cluster_allocation:
                push    ax
                xor     dx,dx
                div     word ptr ds:[sectors_per_cluster]
                pop     ax
                or      dx,dx
                jz      add_rounded_system_bytes
                inc     ax

add_rounded_system_bytes:
                mul     word ptr ds:[bytes_per_sector]
                add     word ptr ds:[system_bytes],ax
                ret

; ------------------------------------------------------------------------
; DX points to a dollar-terminated string in DS; print through DOS AH=09h.
; ------------------------------------------------------------------------

print_string:
                mov     ah,9h
                int     21h
                ret

; ------------------------------------------------------------------------
; Ask whether to format another diskette; terminate on N.
; ------------------------------------------------------------------------

ask_another:
                call    ask_yes_no
                jc      terminate
                call    print_line_end

; ------------------------------------------------------------------------
; Print the shared dollar-terminated line ending.
; ------------------------------------------------------------------------

print_line_end:
                mov     dx,offset msg_line_end
                call    print_string
                ret

; ------------------------------------------------------------------------
; Flush console input and read a key without echo through DOS AX=0C08h.
; ------------------------------------------------------------------------

wait_key:
                mov     ax,0C08h
                int     21h
                ret

; ------------------------------------------------------------------------
; Read Y/N case-insensitively. Return CF=1 for N.
; ------------------------------------------------------------------------

ask_yes_no:
                mov     dx,offset msg_format_another
                call    print_string
                mov     ax,0C01h
                int     21h
                and     al,0DFh
                cmp     al,59h
                jz      ask_yes_no_ret
                cmp     al,4Eh
                jz      answer_no
                call    print_line_end
                jmp     short ask_yes_no

answer_no:
                stc

ask_yes_no_ret:
                ret

print_error_exit:
                call    print_string

terminate:
                int     20h

; ------------------------------------------------------------------------
; Request the DOS diskette used to read system files.
; ------------------------------------------------------------------------

prompt_dos_disk:
                mov     ah,19h
                int     21h
                add     al,41h
                mov     ds:[dos_prompt_drive],al
                mov     dx,offset msg_insert_dos_disk
                call    print_string
                mov     dx,offset msg_press_key
                call    print_string
                call    wait_key
                call    print_line_end
                ret

; ------------------------------------------------------------------------
; DOS AH=1Ch: retrieve FAT pointer and allocation geometry for target_drive.
; ------------------------------------------------------------------------

get_disk_allocation:
                mov     dl,ds:[target_drive]
                inc     dl
                mov     ah,1Ch
                int     21h
                or      bx,bx
                jz      invalid_allocation_drive
                ret

invalid_allocation_drive:
                mov     dx,offset msg_invalid_drive
                jmp     short print_error_exit

; ------------------------------------------------------------------------
; Initialize the FAT media bytes and obtain the target allocation geometry.
; ------------------------------------------------------------------------

initialize_fat:
                call    get_disk_allocation
                mov     word ptr cs:[fat_offset],bx
                mov     word ptr cs:[fat_segment],ds
                mov     al,cs:[media_descriptor]
; Combine selected media type with the FAT reserved-bit pattern.
                or      al,0F8h
                mov     ah,0FFh
                mov     di,word ptr cs:[fat_offset]
                mov     [di],ax
                mov     [di+2h],ah
                mov     byte ptr [di-1h],1h
                push    es
                pop     ds
                mov     ah,0Dh
                int     21h
                call    get_disk_allocation
                push    ds
                push    es
                pop     ds
                mov     word ptr ds:[total_bytes_low],dx
                mov     word ptr ds:[bytes_per_sector],cx
                mov     ah,0h
                mov     word ptr ds:[sectors_per_cluster],ax
                shr     dx,1
                jnc     clear_fat_entries
                inc     dx

; Clear the packed FAT entries after the three media/reserved bytes, then
; remove all directory files.
clear_fat_entries:
                add     dx,word ptr ds:[total_bytes_low]
                xor     ax,ax
                pop     es
                mov     cx,dx
                mov     di,word ptr ds:[fat_offset]
                add     di,3h
; Clear the FAT12 entries while preserving its three-byte header.
                rep     stosb
                mov     di,word ptr ds:[fat_offset]
                mov     byte ptr es:[di-1h],1h
                push    ds
                pop     es
                mov     al,ds:[target_drive]
                inc     al
                mov     ds:[delete_all_drive],al
                mov     ah,13h
; Delete all directory entries using the wildcard extended FCB.
                mov     dx,offset delete_all_ext_fcb
                int     21h
                ret

; ------------------------------------------------------------------------
; Open the BIOS, DOS, and command interpreter files for a /S transfer.
; ------------------------------------------------------------------------

; The extended FCBs select hidden/system files. Keep their dates and times
; for the destination copies.
open_system_files:
                mov     word ptr ds:[transfer_bytes_available],0FFFFh
                mov     ax,ds:[psp_end_segment]
                mov     cx,cs
                sub     ax,cx
                cmp     ax,1000h
                jnl     open_source_dos
                mov     cl,4h
                shl     ax,cl
                mov     word ptr ds:[transfer_bytes_available],ax

open_source_dos:
                mov     ah,0Fh
                mov     dx,offset dos_ext_fcb
                int     21h
                or      al,al
                jz      save_source_dos_timestamp

system_file_open_failed:
                stc
                ret

save_source_dos_timestamp:
                mov     ax,word ptr ds:[dos_file_date]
                mov     word ptr ds:[saved_dos_date],ax
                mov     ax,word ptr ds:[dos_file_time]
                mov     word ptr ds:[saved_dos_time],ax
                mov     ah,0Fh
                mov     dx,offset bios_ext_fcb
                int     21h
                or      al,al
                jnz     system_file_open_failed
                mov     ax,word ptr ds:[bios_file_date]
                mov     word ptr ds:[saved_bios_date],ax
                mov     ax,word ptr ds:[bios_file_time]
                mov     word ptr ds:[saved_bios_time],ax
                mov     ah,1Ah
                mov     dx,word ptr ds:[system_buffer_start]
                int     21h
                mov     word ptr ds:[dos_random_record_low],0h
                mov     word ptr ds:[dos_random_record_high],0h
                mov     word ptr ds:[bios_random_record_low],0h
                mov     word ptr ds:[bios_random_record_high],0h
                mov     word ptr ds:[dos_record_size],1h
                mov     word ptr ds:[bios_record_size],1h
                mov     ah,27h
                mov     dx,offset dos_ext_fcb
                mov     cx,word ptr ds:[transfer_bytes_available]
                sub     cx,word ptr ds:[system_buffer_start]
                mov     word ptr ds:[transfer_bytes_available],cx
                int     21h
                cmp     al,1h
                jnz     system_files_too_large
                mov     word ptr ds:[dos_write_count],cx
                mov     word ptr ds:[dos_file_bytes],cx
                mov     ah,1Ah
                mov     dx,word ptr ds:[system_buffer_start]
                add     dx,word ptr ds:[dos_file_bytes]
                int     21h
                mov     ah,27h
                mov     dx,offset bios_ext_fcb
                mov     cx,word ptr ds:[transfer_bytes_available]
                sub     cx,word ptr ds:[dos_file_bytes]
                mov     word ptr ds:[transfer_bytes_available],cx
                int     21h
                cmp     al,1h
                jnz     system_files_too_large
                mov     word ptr ds:[bios_write_count],cx
                mov     word ptr ds:[bios_file_bytes],cx
                ret

; Block reads must reach EOF; a partial buffer would produce an incomplete
; bootable system.
system_files_too_large:
                jmpn    insufficient_memory_exit

; ------------------------------------------------------------------------
; Write BIOS and DOS system files to the formatted diskette.
; ------------------------------------------------------------------------

write_system_files:
                mov     al,ds:[target_drive]
                inc     al
                mov     ds:[dos_fcb_drive],al
                mov     ds:[bios_fcb_drive],al
                mov     dx,word ptr ds:[system_buffer_start]
                add     dx,word ptr ds:[dos_file_bytes]
                mov     ah,1Ah
                int     21h
                mov     ax,word ptr ds:[saved_bios_date]
                mov     word ptr ds:[output_file_date],ax
                mov     ax,word ptr ds:[saved_bios_time]
; Restore the BIOS file time after writing its buffered contents.
                mov     word ptr ds:[output_file_time],ax
                mov     bx,offset bios_ext_fcb
                call    create_system_file
                mov     ax,word ptr ds:[saved_dos_date]
                mov     word ptr ds:[output_file_date],ax
                mov     ax,word ptr ds:[saved_dos_time]
                mov     word ptr ds:[output_file_time],ax
                mov     dx,word ptr ds:[system_buffer_start]
                mov     ah,1Ah
                int     21h
                mov     bx,offset dos_ext_fcb
; Write the DOS component from the first part of the transfer buffer.
                call    create_system_file
                ret

; BX addresses an extended FCB. Create, write its saved byte count, restore
; its timestamp, then close.
create_system_file:
                xor     ax,ax
                mov     [bx+28h],ax
                mov     [bx+2Ah],ax
                mov     dx,bx
                mov     ah,16h
                int     21h
                mov     word ptr [bx+15h],1h            ; Use one-byte records for the exact saved byte count.
                mov     ah,28h
                mov     cx,[bx+2Ch]
                int     21h
                mov     ax,word ptr ds:[output_file_date]
                mov     [bx+1Bh],ax                     ; Restore the source date in the destination FCB.
                mov     ax,word ptr ds:[output_file_time]
                mov     [bx+1Dh],ax                     ; Restore the source time before closing the file.
                mov     ah,10h
                int     21h
                ret

; ------------------------------------------------------------------------
; Read COMMAND.COM after the buffered BIOS and DOS images; CF reports failure.
; ------------------------------------------------------------------------

read_command_file:
                mov     dx,word ptr ds:[system_buffer_start]
                add     dx,word ptr ds:[dos_file_bytes]
                add     dx,word ptr ds:[bios_file_bytes]
                mov     word ptr ds:[command_buffer],dx
                mov     ah,1Ah
                int     21h
                mov     dx,offset command_fcb
                mov     ah,0Fh
                int     21h
                or      al,al
                jnz     command_file_open_failed
                mov     word ptr ds:[command_random_record_low],0h
                mov     word ptr ds:[command_random_record_high],0h
                mov     word ptr ds:[command_record_size],1h
                mov     cx,word ptr ds:[transfer_bytes_available]
                sub     cx,word ptr ds:[bios_file_bytes]
                mov     ax,word ptr ds:[command_file_date]
                mov     word ptr ds:[saved_command_date],ax
                mov     ax,word ptr ds:[command_file_time]
                mov     word ptr ds:[saved_command_time],ax
                mov     ah,27h
                int     21h
                cmp     al,1h
                jnz     insufficient_memory_exit
                mov     word ptr ds:[command_file_bytes],cx
                ret

command_file_open_failed:
                jmp     short file_transfer_failed
                nop

insufficient_memory_exit:
                mov     dx,offset msg_insufficient_memory
                call    print_string
                jmpn    terminate

; ------------------------------------------------------------------------
; Create and write COMMAND.COM on the target diskette.
; ------------------------------------------------------------------------

write_command_file:
                mov     al,ds:[target_drive]
                inc     al
                mov     ds:[command_fcb],al
                mov     dx,offset command_fcb
                mov     ah,16h
                int     21h
                or      al,al
                jnz     file_transfer_failed
                mov     dx,word ptr ds:[command_buffer]
                mov     ah,1Ah
                int     21h
                mov     word ptr ds:[command_random_record_low],0h
                mov     word ptr ds:[command_random_record_high],0h
                mov     word ptr ds:[command_record_size],1h
                mov     dx,offset command_fcb
                mov     ah,28h
                mov     cx,word ptr ds:[command_file_bytes]
                int     21h
                or      al,al
                jnz     file_transfer_failed
                mov     ax,word ptr ds:[saved_command_date]
                mov     word ptr ds:[command_file_date],ax
                mov     ax,word ptr ds:[saved_command_time]
                mov     word ptr ds:[command_file_time],ax
                mov     dx,offset command_fcb
                mov     ah,10h
                int     21h
                or      al,al
                jnz     file_transfer_failed
                ret

file_transfer_failed:
                stc
                ret

msg_insert_blank_disk    label   byte
                db      "Insert new diskette for drive "

target_prompt_drive      label   byte
                db      "x:"
                db      0Dh,0Ah
                db      "$"

msg_press_key            label   byte
                db      "and strike any key when ready$"

msg_system_transferred   label   byte
                db      "System transferred"
                db      0Dh,0Ah
                db      "$"

msg_format_another       label   byte
                db      "Format another (Y/N)?$"

msg_line_end             label   byte
                db      0Dh,0Ah
                db      "$"

msg_invalid_drive        label   byte
                db      "Invalid drive specification$"

msg_invalid_parameter    label   byte
                db      "Invalid parameter$"

msg_insert_dos_disk      label   byte
                db      "Insert DOS disk in drive "

dos_prompt_drive         label   byte
                db      "x:"
                db      0Dh,0Ah
                db      "$"

msg_format_failure       label   byte
                db      "Format failure"
                db      0Dh,0Ah,0Dh,0Ah
                db      "$"

msg_fatal_format_error   label   byte
                db      "Fatal format error"
                db      0Dh,0Ah
                db      "$"

msg_system_disk_unsuitable label   byte
                db      "Disk unsuitable for system disk"
                db      0Dh,0Ah
                db      "$"

msg_track_zero_bad       label   byte
                db      "Track 0 bad - disk unusable"
                db      0Dh,0Ah
                db      "$"

msg_insufficient_memory  label   byte
                db      "Insufficient memory for system transfer"
                db      0Dh,0Ah
                db      "$"

msg_total_bytes          label   byte
                db      " bytes total disk space"
                db      0Dh,0Ah
                db      "$"

msg_system_bytes         label   byte
                db      " bytes used by system"
                db      0Dh,0Ah
                db      "$"

msg_bad_sector_bytes     label   byte
                db      " bytes in bad sectors"
                db      0Dh,0Ah
                db      "$"

msg_available_bytes      label   byte
                db      " bytes available on disk"
                db      0Dh,0Ah,0Dh,0Ah
                db      "$"

; Reused byte: drive operand seen during parsing; system space counted
; during formatting.
phase_flag               label   byte
                db      0h

fat_initialized          label   byte
                db      0h

target_drive             label   byte
                db      0h

original_drive           label   byte
                db      0h

output_file_date         label   word
                dw      0

saved_bios_date          label   word
                dw      0

saved_dos_date           label   word
                dw      0

saved_command_date       label   word
                dw      0

output_file_time         label   word
                dw      0

saved_bios_time          label   word
                dw      0

saved_dos_time           label   word
                dw      0

saved_command_time       label   word
                dw      0

command_buffer           label   word
                dw      0

bios_file_bytes          label   word
                dw      0

dos_file_bytes           label   word
                dw      0

command_file_bytes       label   word
                dw      0

transfer_bytes_available label   word
                dw      0

bios_ext_fcb             label   byte
                db      0FFh,0h,0h,0h,0h,0h,6h

bios_fcb_drive           label   byte
                db      0h

IF MSVER

bio_filename             label   byte
                db      "IO      SYS"
ELSE

bio_filename             label   byte
                db      "IBMBIO  COM"
ENDIF
                db      4h,0h

bios_record_size         label   word
                db      0h,0h,0h,0h,0h,0h

bios_file_date           label   word
                dw      0

bios_file_time           label   word
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

bios_random_record_low   label   word
                dw      0

bios_random_record_high  label   word
                dw      0

bios_write_count         label   word
                dw      0

dos_ext_fcb              label   byte
                db      0FFh,0h,0h,0h,0h,0h,6h

dos_fcb_drive            label   byte
                db      0h

IF MSVER

dos_filename             label   byte
                db      "MSDOS   SYS"
ELSE

dos_filename             label   byte
                db      "IBMDOS  COM"
ENDIF
                db      4h,0h

dos_record_size          label   word
                db      0h,0h,0h,0h,0h,0h

dos_file_date            label   word
                dw      0

dos_file_time            label   word
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

dos_random_record_low    label   word
                dw      0

dos_random_record_high   label   word
                dw      0

dos_write_count          label   word
                dw      0

command_fcb              label   byte
                db      0h
                db      "COMMAND COM"
                db      0h,0h

command_record_size      label   word
                db      0h,0h,0h,0h,0h,0h

command_file_date        label   word
                dw      0

command_file_time        label   word
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

command_random_record_low label   word
                dw      0

command_random_record_high label   word
                db      0h,0h,0h

delete_all_ext_fcb       label   byte
                db      0FFh,0h,0h,0h,0h,0h,6h

delete_all_drive         label   byte
                db      0h
                db      "???????????"
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h

format_options           label   word
                dw      0

saved_options            label   word
                dw      0

fat_offset               label   word
                dw      0

fat_segment              label   word
                dw      0

sectors_per_cluster      label   word
                dw      0

bytes_per_sector         label   word
                dw      0

; Rounded BIOS + DOS + COMMAND allocation size on the destination.
system_bytes             label   word
                dw      0

total_bytes_low          label   word
                dw      0

total_bytes_high         label   word
                dw      0

bad_bytes_low            label   word
                dw      0

bad_bytes_high           label   word
                dw      0

system_sector_limit      label   word
                dw      0

bad_sector_count         label   word
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h

stack_top                label   byte
                db      0E8h,0Ch

; ------------------------------------------------------------------------
; Hardware completion hook: this implementation simply returns with CF
; clear.
; ------------------------------------------------------------------------

hardware_finish:
                clc
                ret

; ------------------------------------------------------------------------
; Initialize BIOS drive state, probe heads, and choose single/double-sided
; geometry.
; ------------------------------------------------------------------------

; Probe cylinder zero before the main format pass; a missing second side
; selects single-sided geometry.
hardware_initialize:
                mov     al,ds:[target_drive]
                mov     ds:[bios_drive],al
                push    ds
                mov     bx,50h
                mov     ds,bx
; DOS remembers which diskette is currently selected on a one-drive machine.
                mov     ds:[dos_last_diskette],al
                pop     ds
                int     11h
                and     ax,0C0h
                jnz     initialize_disk_geometry
                mov     byte ptr ds:[bios_drive],0h     ; BIOS sees a single physical drive as drive zero.

initialize_disk_geometry:
                mov     byte ptr ds:[current_head],1h
                mov     byte ptr ds:[current_cylinder],0h
                mov     byte ptr ds:[initial_track_bad],0h
                mov     byte ptr ds:[media_descriptor],0FFh
                mov     word ptr ds:[reserved_sectors],9h
                test    word ptr ds:[format_options],option_single_side
                jz      show_formatting_status
                mov     byte ptr ds:[media_descriptor],0FEh
                mov     word ptr ds:[reserved_sectors],6h

show_formatting_status:
                mov     dx,offset msg_formatting
                call    hardware_print
                mov     byte ptr ds:[retry_count],3h

reset_probe_attempt:
                call    reset_disk
                jnc     begin_track_zero_probe
                call    handle_disk_error
                cmp     byte ptr ds:[retry_count],0h
                jnz     reset_probe_attempt

begin_track_zero_probe:
                mov     byte ptr ds:[retry_count],3h

format_track_zero_attempt:
                mov     dh,ds:[current_head]
                mov     ch,0h
                call    format_track
                jnc     next_track_zero_head
                call    handle_disk_error
                cmp     byte ptr ds:[retry_count],0h
                jnz     format_track_zero_attempt
; Report the initial cylinder as bad through the normal bad-range interface.
                mov     byte ptr ds:[initial_track_bad],1h
                clc
                ret

; Format head zero after head one, then verify both before accepting the
; geometry.
next_track_zero_head:
                mov     byte ptr ds:[retry_count],3h
                dec     byte ptr ds:[current_head]
                jz      format_track_zero_attempt
                inc     byte ptr ds:[current_head]
                mov     byte ptr ds:[format_state],0h

verify_track_zero_attempt:
                mov     dh,ds:[current_head]
                mov     ch,0h
                call    verify_track
                jnc     check_probe_head_count
                call    handle_disk_error
                cmp     byte ptr ds:[retry_count],0h
                jnz     verify_track_zero_attempt
                cmp     byte ptr ds:[current_head],0h
                jnz     fall_back_single_sided
                mov     byte ptr ds:[initial_track_bad],1h
                clc
                ret

; Only a failed second-head verification can fall back; failure on head zero
; marks track zero bad.
fall_back_single_sided:
                mov     byte ptr ds:[media_descriptor],0FEh
                mov     word ptr ds:[reserved_sectors],6h

check_probe_head_count:
                cmp     byte ptr ds:[media_descriptor],0FEh
                jz      begin_data_cylinders
                mov     byte ptr ds:[retry_count],3h
                inc     byte ptr ds:[current_head]
                cmp     byte ptr ds:[current_head],1h
                jz      verify_track_zero_attempt

begin_data_cylinders:
                inc     byte ptr ds:[current_cylinder]
                mov     byte ptr ds:[current_head],0h
                clc
                ret

; ------------------------------------------------------------------------
; Reset the floppy controller through BIOS INT 13h AH=00h.
; ------------------------------------------------------------------------

reset_disk:
                mov     al,8h
                mov     cx,1h
                mov     dl,ds:[bios_drive]
                xor     dh,dh
                mov     ah,0h
                int     13h
                ret

; ------------------------------------------------------------------------
; Populate track/head bytes in eight sector IDs and call BIOS format AH=05h.
; ------------------------------------------------------------------------

format_track:
                mov     di,1h
                mov     bx,offset bios_drive
                mov     al,8h

; Update cylinder/head pairs in the eight CHRN descriptors, leaving sector
; numbers and size codes intact.
fill_sector_chrn:
                sub     bx,4h
                mov     [bx],ch
                mov     [bx+di],dh
                dec     al
                jnz     fill_sector_chrn
                mov     dl,ds:[bios_drive]
                mov     ax,508h
                int     13h
                ret

; ------------------------------------------------------------------------
; Verify eight sectors through BIOS INT 13h AH=04h.
; ------------------------------------------------------------------------

verify_track:
                mov     al,8h
                mov     cl,1h
                mov     ah,4h
                int     13h
                ret

; ------------------------------------------------------------------------
; Handle write protection and not-ready errors; reset and decrement retry
; count.
; ------------------------------------------------------------------------

handle_disk_error:
                cmp     ah,3h
                jnz     check_disk_not_ready
                mov     dx,offset msg_write_protected

; Discard the helper return address so write-protect/not-ready errors return
; directly to the format caller.
abort_disk_operation:
                call    hardware_print
                mov     ah,0h
                int     13h
                add     sp,2h                           ; Bypass the intermediate formatter helper when aborting.
                jmpn    hardware_error_ret

check_disk_not_ready:
                cmp     ah,80h
                jnz     reset_after_disk_error
                mov     dx,offset msg_drive_not_ready
                jmp     short abort_disk_operation

reset_after_disk_error:
                mov     ah,0h
                int     13h
                dec     byte ptr ds:[retry_count]
                ret

; ------------------------------------------------------------------------
; Format and verify tracks, returning bad sector ranges or zero on
; completion.
; ------------------------------------------------------------------------

format_next_tracks:
                mov     byte ptr ds:[retry_count],3h
                cmp     byte ptr ds:[initial_track_bad],0h
                jz      reset_format_attempt
                mov     byte ptr ds:[initial_track_bad],0h
                mov     bx,0h
                mov     ax,8h
                clc
                ret

reset_format_attempt:
                call    reset_disk
                jnc     prepare_format_track
                call    handle_disk_error
                cmp     byte ptr ds:[retry_count],0h
                jnz     reset_format_attempt

prepare_format_track:
                mov     byte ptr ds:[retry_count],3h
                mov     byte ptr ds:[format_state],1h

format_data_track_attempt:
                mov     dh,ds:[current_head]
                mov     ch,ds:[current_cylinder]
                call    format_track
                jnc     prepare_verify_track
                call    handle_disk_error
                cmp     byte ptr ds:[retry_count],0h
                jnz     format_data_track_attempt
                jmpn    report_bad_track

prepare_verify_track:
                mov     byte ptr ds:[retry_count],3h
                mov     byte ptr ds:[format_state],0h

verify_data_track_attempt:
                mov     dh,ds:[current_head]
                mov     ch,ds:[current_cylinder]
                call    verify_track
                jnc     advance_formatted_track
                call    handle_disk_error
                cmp     byte ptr ds:[retry_count],0h
                jnz     verify_data_track_attempt
                jmp     short report_bad_track
                nop

; Advance the head before the cylinder; single-sided media skip head one
; entirely.
advance_formatted_track:
                cmp     byte ptr ds:[media_descriptor],0FEh
                jz      advance_format_cylinder
                inc     byte ptr ds:[current_head]
                cmp     byte ptr ds:[current_head],1h
                jnz     wrap_to_first_head
                jmp     short prepare_format_track

wrap_to_first_head:
                mov     byte ptr ds:[current_head],0h

advance_format_cylinder:
                mov     ch,ds:[current_cylinder]
                inc     ch
                mov     ds:[current_cylinder],ch
                cmp     ch,28h
                jz      write_boot_sector
                jmp     short prepare_format_track

; ------------------------------------------------------------------------
; Write the embedded 512-byte boot image through DOS INT 26h; pop its saved
; flags.
; ------------------------------------------------------------------------

; The template loads from sector 8 on one side; double-sided media need CHS
; 01/0/3 instead.
write_boot_sector:
                mov     bx,offset boot_image
                cmp     byte ptr ds:[media_descriptor],0FEh
                jz      write_boot_image
                mov     word ptr [bx+3h],103h           ; Patch the loader start to cylinder 1, head 0, sector 3.

; INT 26h leaves a flags word on the stack in addition to its normal return;
; both paths must pop it.
write_boot_image:
                mov     dx,0h
                mov     cx,1h
                mov     ah,0h
                mov     al,ds:[target_drive]
                int     26h
                jc      boot_write_failed
                mov     dx,offset msg_format_complete
                call    hardware_print
                popf                                    ; Discard the extra flags word left by absolute disk write.
                xor     ax,ax
                clc
                ret

boot_write_failed:
                popf                                    ; The failure return leaves that same extra flags word.
                mov     dx,offset msg_boot_write_error
                call    hardware_print

hardware_error_ret:
                stc
                ret

; ------------------------------------------------------------------------
; Compute the failed track sector range and advance the hardware formatting
; cursor.
; ------------------------------------------------------------------------

; Return an eight-sector logical range, then advance the geometry cursor so
; the caller can continue.
report_bad_track:
                mov     bh,0h
                mov     bl,ds:[current_cylinder]
                cmp     byte ptr ds:[media_descriptor],0FEh
                jz      bad_track_to_sectors
                shl     bl,1
                add     bl,ds:[current_head]

bad_track_to_sectors:
                shl     bx,1
                shl     bx,1
; Eight sectors per track convert the track index into a logical sector
; number.
                shl     bx,1
                mov     ax,8h
                cmp     byte ptr ds:[media_descriptor],0FEh
                jz      advance_after_bad_cylinder
                cmp     byte ptr ds:[current_head],1h
                jz      advance_after_bad_cylinder
                inc     byte ptr ds:[current_head]
                jmp     short bad_track_range_ret

advance_after_bad_cylinder:
                inc     byte ptr ds:[current_cylinder]
                mov     byte ptr ds:[current_head],0h

bad_track_range_ret:
                clc
                ret

; ------------------------------------------------------------------------
; Display a dollar-terminated hardware status string at DS:DX.
; ------------------------------------------------------------------------

hardware_print:
                mov     ah,9h
                int     21h
                ret

option_count             label   byte
                db      2h

option_chars             label   byte
                db      "1S"

msg_formatting           label   byte
                db      "Formatting...$0"

msg_format_complete      label   byte
                db      "Format complete"
                db      0Dh,0Ah
                db      "$"

msg_write_protected      label   byte
                db      0Dh,0Ah
                db      "Attempted write-protect violation"
                db      0Dh,0Ah
                db      "$"

msg_boot_write_error     label   byte
                db      0Dh,0Ah
                db      "Unable to write BOOT"
                db      0Dh,0Ah
                db      "$"

msg_drive_not_ready      label   byte
                db      0Dh,0Ah
                db      "Drive not ready"
                db      0Dh,0Ah
                db      "$"

format_id_table          label   byte
                db      0h,0h,1h,2h,0h,0h,2h,2h,0h,0h,3h,2h
                db      0h,0h,4h,2h,0h,0h,5h,2h,0h,0h,6h,2h
                db      0h,0h,7h,2h,0h,0h,8h,2h

bios_drive               label   byte
                db      0h

current_cylinder         label   byte
                db      0h

current_head             label   byte
                db      0h

; Hardware phase: 1 while formatting, 0 while verifying.
format_state             label   byte
                db      0h

initial_track_bad        label   byte
                db      0h

retry_count              label   byte
                db      0h

; FEh for one side; FFh for two sides.
media_descriptor         label   byte
                db      0h

; First data-area sector: 6 for one side, 9 for two sides.
reserved_sectors         label   word
                dw      0

; Start of system-transfer storage; initialization/boot storage can be
; reused.
system_buffer_start      label   word
                db      0E8h,0Eh

boot_image               label   byte
                include fmtboot.inc

trailing_bytes           label   byte
                db      88h,0h,0EBh
                db      "C"
                db      8Ah
                db      "^"
                db      0Ah,0B7h,0h,0D1h,0E3h,8Bh,87h,92h
                db      ";"
                db      89h
                db      "F"
                db      0FCh,8Bh
                db      "F"
                db      8h,89h
                db      "F"
                db      0FAh,8Ah
                db      "^"
                db      0Ah,0B7h,0h,8Ah,87h,95h
                db      "8"
                db      88h
                db      "F"
                db      0F9h,0B4h,0h,0D1h,0E0h,89h,0C3h,0FFh,87h,98h
                db      "4"
                db      0B8h,5h,0h
                db      "P"
                db      8Dh
                db      "F"
                db      0F9h
                db      "P"
                db      0B0h,2h
                db      "P"
                db      0FFh
                db      "64"
                db      1Ch,9Ah,14h,0Ah
                db      "r"
                db      4h,83h,6h
                db      "4"
                db      1Ch,5h,89h,0ECh
                db      "]"
                db      0CAh,6h,0h
                db      "U"
                db      8Bh,0ECh
                db      "Q"
                db      0B8h,1Eh,3h
                db      "P"
                db      9Ah
                db      "<"
                db      0h
                db      "O"
                db      4h,9Ah
                db      "2"
                db      1h,0E8h,5h,0B8h
                db      "#"
                db      3h
                db      "P"
                db      9Ah
                db      "<"
                db      0h
                db      "O"
                db      4h,8Ah,1Eh
                db      "T"
                db      1Eh,0B7h,0h,0D1h,0E3h,8Bh
                db      "F"
                db      6h
                db      "+"
                db      87h,9Dh
                db      "/P"
                db      0B0h,4h
                db      "P"
                db      9Ah,15h,1h
                db      "O"
                db      4h,9Ah
                db      "="
                db      1h
                db      "O"
                db      4h,89h,0ECh
                db      "]"
                db      0CAh,2h,0h
                db      "U"
                db      8Bh,0ECh
                db      "Q"
                db      0A1h,0Ch,1Ch,89h
                db      "F"
                db      0FEh,0C7h,6h,0Ch,1Ch,0h,0h,0B8h
                db      "*"
                db      3h
                db      "P"
                db      9Ah,83h,0h,0E8h,5h,0FFh
                db      "v"
                db      4h,9Ah,85h,3h,80h,5h,83h
                db      "~"
                db      0FEh,0h
                db      "t"
                db      0Dh,8Bh
                db      "F"
                db      0FEh,0A3h,0Ch,1Ch,0C7h
                db      "F"
                db      0FEh,0h,0h,0EBh,0DCh,89h,0ECh
                db      "]"
                db      0C2h,2h,0h
                db      "U"
                db      8Bh,0ECh,83h,0ECh,16h,9Ah
                db      "K"
                db      1h
                db      "O"
                db      4h,0B4h,0h,89h
                db      "F"
                db      0FEh,8Bh
                db      "F"
                db      6h,0B1h,8h,0D3h,0E0h,3h
                db      "F"
                db      0FEh,89h
                db      "F"
                db      0F4h,8Bh,0Eh,1Ch,1Ch,3h,0C8h,89h
                db      "N"
                db      0F8h,5h,8Dh
                db      "@"
                db      89h
                db      "F"
                db      0F6h,8Dh
                db      "F"
                db      0EAh
                db      "P"
                db      8Dh
                db      "F"
                db      0EBh
                db      "P"
                db      8Dh
                db      "F"
                db      0FCh
                db      "P"
                db      8Dh
                db      "F"
                db      0F0h

program         ends
                end     start
