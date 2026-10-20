; *-------------------------------------------------------------------------
; MODE.ASM - PC DOS 1.10 display, printer and serial configuration
;
; Build: make mode.com     Verify: make check-utilities
; Original: reference/mode.com, 2509 bytes; COM load address 0100h.
; Comments describe intent and register/state contracts.
; Exact addresses and bytes are kept in mappings/ and verified on rebuild.
; Reassembly is exact; runtime testing is a separate verification step.
;
; Layout:
; 0100h-0105h  code
; 02C6h-033Eh  code
; 03B2h-0503h  code
; 0548h-0604h  code
; 0615h-065Bh  code
; 0662h-068Dh  code
; 06B4h-074Bh  code
; 0751h-0780h  code
; 0808h-08C9h  code
; 0918h-0ACCh  code
; All remaining image bytes are initialized data, messages, or tables.
; MODE copies interrupt handler templates to segment 0000h at 0580h.
; -------------------------------------------------------------------------

program         segment
                assume  cs:program, ds:program
                org     100h

; Preserve near jumps even when the target is in short range.
jmpn            macro   target
                db      0E9h
                dw      target - $ - 2
                endm

; Literal far pointers are patched with the saved BIOS vectors before
; installation.
jmp_far                 macro   segval, offval
                db      0EAh
                dw      offval, segval
                endm
call_far                macro   segval, offval
                db      9Ah
                dw      offval, segval
                endm

 ; Relocated handler storage lives in segment zero, outside the COM image.
resident_lpt_state       equ     05F0h
resident_com_by_lpt      equ     05F1h
resident_serial_branch   equ     0583h
resident_printer_branch  equ     05C3h

; PSP fields and fixed data addresses (equates do not emit bytes).

; External memory fields and resident patch locations; image data is labeled
; below.
int14_vector_offset      equ     50h
int14_vector_segment     equ     52h
int17_vector_offset      equ     5Ch
int17_vector_segment     equ     5Eh
video_table_vector_offset equ     74h
video_table_vector_segment equ     76h
command_length           equ     80h
command_tail             equ     81h
crt_sync_40col           equ     92h
crt_sync_80col           equ     0A2h
crt_sync_graphics        equ     0B2h
bios_ctrl_break_flag     equ     471h
resident_retry_mask      equ     5BBh
printer_test_patch       equ     5C2h
printer_branch_displacement equ     5C4h
saved_int14_jump_offset  equ     chain_original_serial + 1
saved_int14_jump_segment equ     chain_original_serial + 3
saved_int17_jump_offset  equ     chain_original_printer + 1
saved_int17_jump_segment equ     chain_original_printer + 3

; ------------------------------------------------------------------------
; Code and initialized data in original file order
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; Set the transient stack at 0100h and enter command parsing.
; ------------------------------------------------------------------------

start:
                mov     sp,100h
                jmpn    parse_command

command_buffer           label   byte
                db      0h,0h,0h

device_number            label   byte
                db      0h

device_colon             label   byte
                db      0h

device_argument          label   byte
                db      0h,0h,0h,0h

redirect_com_number      label   byte
                db      0h

second_argument          label   byte
                db      0h

third_argument           label   byte
                db      0h

video_mode               label   byte
                db      0h

comma_count              label   byte
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      "The IBM Personal Computer Mode command Version 1.10 "
                db      "(C)Copyright IBM Corp 1982 Licensed Material - Program "
                db      "Property of IBM Authors - Mel Hallerman, Ron Heiney, and Ed "
                db      "Kiser"

; ------------------------------------------------------------------------
; Split the PSP command tail into the device and comma-separated arguments.
; ------------------------------------------------------------------------

; The return address zero terminates through the PSP. Device arguments are
; split into fixed work fields.
parse_command:
                mov     cx,0h
                push    cx
                mov     cl,ds:[command_length]
                jcxz    invalid_command
                mov     bp,command_tail
                mov     bx,offset command_buffer

scan_command_character:
                mov     al,es:[bp+0h]
                cmp     al,20h
                jz      advance_command_scan
                cmp     al,2Ch
                jnz     store_argument_character
                cmp     byte ptr ds:[comma_count],2h
                jz      start_last_argument
                cmp     byte ptr ds:[comma_count],1h
                jz      start_third_argument
                mov     byte ptr ds:[comma_count],1h
                mov     bx,offset second_argument
                jmp     short finish_comma_field

start_third_argument:
                mov     byte ptr ds:[comma_count],2h
                mov     bx,offset third_argument

finish_comma_field:
                jmp     short skip_argument_separator

start_last_argument:
                mov     bx,offset video_mode

skip_argument_separator:
                jmp     short advance_command_scan

store_argument_character:
                mov     [bx],al
                inc     bx

advance_command_scan:
                cmp     bx,112h
                jz      dispatch_device_command
                inc     bp
                loop    scan_command_character

; Only the first device letter selects LPT, COM or the numeric video-mode
; path.
dispatch_device_command:
                or      byte ptr ds:[command_buffer],20h
                cmp     byte ptr ds:[command_buffer],6Ch
                jnz     check_serial_command
                call    set_printer_mode
                jmp     short command_complete

check_serial_command:
                cmp     byte ptr ds:[command_buffer],63h
                jnz     dispatch_video_command
                call    set_serial_mode
                jmp     short command_complete

dispatch_video_command:
                call    set_video_mode

command_complete:
                jmp     short command_ret

invalid_command:
                mov     dx,offset msg_invalid_parameters
                mov     ah,9h
                int     21h

command_ret:
                ret
                db      0h

video_done               label   byte
                db      0h

invalid_video_option     label   byte
                db      1h

test_digits              label   byte
                db      "0123456789$"

msg_rightmost_nine       label   byte
                db      0Dh,0Ah
                db      "Do you see the rightmost 9? (Y/N) "
                db      0Dh,0Ah
                db      "$"

msg_leftmost_zero        label   byte
                db      0Dh,0Ah
                db      "Do you see the leftmost 0? (Y/N) "
                db      0Dh,0Ah
                db      "$"

msg_invalid_parameters   label   byte
                db      0Dh,0Ah
                db      "Invalid parameters"
                db      7h,0Dh,0Ah
                db      "$"

; ------------------------------------------------------------------------
; Copy the BIOS video parameter table to 0040:0090 if needed; return
; DS=0040h.
; ------------------------------------------------------------------------

; INT 1Dh points at BIOS CRT parameters. Copy them to RAM before changing
; horizontal sync values.
copy_video_table:
                push    es
                mov     ax,0h
                mov     ds,ax
                mov     bx,ds:[video_table_vector_segment]
                cmp     bx,40h
                jz      use_video_table_segment
                mov     di,90h
                mov     ax,40h
                mov     es,ax
                mov     si,ds:[video_table_vector_offset]
; Redirect the BIOS parameter vector to the writable RAM copy.
                mov     ds:[video_table_vector_offset],di
                mov     word ptr ds:[video_table_vector_segment],es
; DS now addresses the old table while ES addresses its destination.
                mov     ds,bx
                mov     cx,20h
                rep     movsw

; Return DS=0040h so the caller edits the copied CRT table rather than the
; COM image.
use_video_table_segment:
                mov     ax,40h
                mov     ds,ax
                pop     es
                ret

; ------------------------------------------------------------------------
; Configure 40/80 columns and horizontal alignment; optionally show a test
; pattern.
; ------------------------------------------------------------------------

set_video_mode:
                mov     bp,offset command_buffer
                call    parse_decimal
                mov     ah,0Fh
                mov     al,0h
                int     10h
                mov     ds:[video_mode],al
                cmp     bl,28h
                jnz     check_eighty_columns
                mov     byte ptr ds:[invalid_video_option],0h
                and     byte ptr ds:[video_mode],1h
                mov     ah,0h
                mov     al,ds:[video_mode]
                int     10h
                jmp     short begin_alignment

check_eighty_columns:
                cmp     bl,50h
                jnz     begin_alignment
                mov     byte ptr ds:[invalid_video_option],0h
                or      byte ptr ds:[video_mode],2h
                mov     ah,0h
                mov     al,ds:[video_mode]
                int     10h

begin_alignment:
                mov     byte ptr ds:[video_done],0h

adjust_horizontal_position:
                or      byte ptr ds:[second_argument],20h
                cmp     byte ptr ds:[second_argument],72h
                jnz     check_shift_left
                mov     byte ptr ds:[invalid_video_option],0h
                call    copy_video_table
                mov     al,ds:[crt_sync_40col]
                sub     al,1h
; Decrease the 40-column horizontal-sync position by one step.
                mov     ds:[crt_sync_40col],al
                mov     al,ds:[crt_sync_80col]
                sub     al,2h
                mov     ds:[crt_sync_80col],al          ; The 80-column table uses two clock units per adjustment.
                mov     al,ds:[crt_sync_graphics]
                sub     al,1h
                mov     ds:[crt_sync_graphics],al
                jmp     short apply_video_table

check_shift_left:
                cmp     byte ptr ds:[second_argument],6Ch
                jnz     alignment_not_requested
                mov     byte ptr ds:[invalid_video_option],0h
                call    copy_video_table
                mov     al,ds:[crt_sync_40col]
                add     al,1h
                mov     ds:[crt_sync_40col],al
                mov     al,ds:[crt_sync_80col]
                add     al,2h
                mov     ds:[crt_sync_80col],al
                mov     al,ds:[crt_sync_graphics]
                add     al,1h
                mov     ds:[crt_sync_graphics],al
                jmp     short apply_video_table

alignment_not_requested:
                mov     byte ptr cs:[video_done],1h

; Restore DS=CS after editing BIOS-area data, then reset the current video
; mode to reload the table.
apply_video_table:
                mov     ax,cs
                mov     ds,ax                           ; Return from BIOS-data addressing to program variables.
                cmp     byte ptr ds:[video_done],1h
                jz      check_video_parameters
                mov     ah,0Fh
                mov     al,0h
                int     10h
                mov     ds:[video_mode],al
                mov     ah,0h
                int     10h
                or      byte ptr ds:[third_argument],20h
                cmp     byte ptr ds:[third_argument],74h
                jnz     accept_without_test
                or      byte ptr ds:[video_mode],1h
                mov     cx,8h
                cmp     byte ptr ds:[video_mode],1h
                jnz     print_test_digit_row
                mov     cx,4h

; Fill one display line with 0..9 so the user can judge the adjusted
; horizontal position.
print_test_digit_row:
                mov     dx,offset test_digits
                mov     ah,9h
                int     21h
                loop    print_test_digit_row
                cmp     byte ptr ds:[second_argument],72h
                jnz     ask_rightmost_digit
                mov     dx,offset msg_leftmost_zero
                jmp     short read_alignment_answer

ask_rightmost_digit:
                mov     dx,offset msg_rightmost_nine

read_alignment_answer:
                mov     ah,9h
                int     21h
                mov     ax,0C01h
                int     21h
                or      al,20h
                cmp     al,79h
                jnz     check_alignment_answer
                mov     byte ptr ds:[video_done],1h

check_alignment_answer:
                jmp     short repeat_alignment_if_needed

accept_without_test:
                mov     byte ptr ds:[video_done],1h

; A negative answer repeats the same one-step adjustment; an accepted
; position ends the loop.
repeat_alignment_if_needed:
                cmp     byte ptr ds:[video_done],1h
                jz      check_video_parameters
                jmpn    adjust_horizontal_position

check_video_parameters:
                cmp     byte ptr ds:[invalid_video_option],0h
                jz      video_mode_ret
                mov     dx,offset msg_invalid_parameters
                mov     ah,9h
                int     21h

video_mode_ret:
                ret

printer_work             label   byte
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h

msg_printer_redirected   label   byte
                db      0Dh,0Ah
                db      "LPT"

redirect_lpt_digit       label   byte
                db      " : redirected to COM"

redirect_com_digit       label   byte
                db      " :"
                db      0Dh,0Ah
                db      "$"

msg_printer_not_redirected label   byte
                db      0Dh,0Ah
                db      "LPT"

unredirect_lpt_digit     label   byte
                db      " : not redirected."
                db      0Dh,0Ah
                db      "$"

; ------------------------------------------------------------------------
; Select LPT1..3. Return AH=printer mask, SI=printer number; AH=0 on invalid
; name.
; ------------------------------------------------------------------------

; Return AH as the LPT bit mask and SI as its one-based table index; ES
; addresses segment zero.
select_printer:
                call    install_resident
                sub     ax,ax
                mov     es,ax
                mov     al,ds:[device_number]
                mov     ds:[redirect_lpt_digit],al
                mov     ds:[unredirect_lpt_digit],al
                cmp     al,31h
                jnz     check_lpt2
                mov     ah,1h
                mov     si,1h
                jmp     short select_printer_ret

check_lpt2:
                cmp     al,32h
                jnz     check_lpt3
                mov     ah,2h
                mov     si,2h
                jmp     short select_printer_ret

check_lpt3:
                cmp     al,33h
                jnz     invalid_printer_device
                mov     ah,4h
                mov     si,3h
                jmp     short select_printer_ret

invalid_printer_device:
                mov     dx,offset msg_illegal_device
                mov     ah,9h
                int     21h
                mov     ah,0h

select_printer_ret:
                ret

; ------------------------------------------------------------------------
; Redirect an LPT device to COM1 or COM2 using the resident INT 17h handler.
; ------------------------------------------------------------------------

redirect_printer:
                push    es
                call    select_printer
                cmp     ah,0h
                jz      redirect_printer_ret
                mov     dl,0h
                mov     al,ds:[redirect_com_number]
                mov     ds:[redirect_com_digit],al
                cmp     al,31h
                jnz     check_redirect_com2
                mov     dl,1h
                jmp     short apply_printer_redirect

check_redirect_com2:
                cmp     al,32h
                jnz     invalid_redirect_device
                mov     dl,2h
                jmp     short apply_printer_redirect

invalid_redirect_device:
                push    dx
                mov     dx,offset msg_illegal_device
                mov     ah,9h
                int     21h
                pop     dx

; Store a zero-based COM number in the resident per-printer table and enable
; its LPT mask bit.
apply_printer_redirect:
                cmp     dl,0h
                jz      redirect_printer_ret
                or      ah,es:[resident_lpt_state]
                mov     es:[resident_lpt_state],ah
                dec     dl
                mov     es:[si+resident_lpt_state],dl
                call    patch_printer_dispatch
                mov     dx,offset msg_printer_redirected
                mov     ah,9h
                int     21h

redirect_printer_ret:
                pop     es
                ret

; ------------------------------------------------------------------------
; Clear an LPT redirection bit and repatch the resident printer dispatch.
; ------------------------------------------------------------------------

unredirect_printer:
                push    es
                call    select_printer
                cmp     ah,0h
                jz      unredirect_printer_ret
                xor     ah,0FFh
                and     ah,es:[resident_lpt_state]
                mov     es:[resident_lpt_state],ah
                call    patch_printer_dispatch
                mov     dx,offset msg_printer_not_redirected
                mov     ah,9h
                int     21h

unredirect_printer_ret:
                pop     es
                ret

; ------------------------------------------------------------------------
; Use the redirection mask to select a patch from printer_dispatch_table.
; ------------------------------------------------------------------------

; The mask chooses tests/branches patched into the resident INT 17h entry,
; not a new interrupt hook.
patch_printer_dispatch:
                mov     al,es:[resident_lpt_state]
; Every selected mask branch uses this common five-byte displacement.
                mov     byte ptr es:[printer_branch_displacement],5h
                mov     ah,0h
                shl     al,1
                mov     si,ax
; One entry for each combination of the three LPT redirect bits.
                jmp     word ptr [si+printer_dispatch_table]

printer_dispatch_table   label   byte
                dw      offset redirect_no_printers
                dw      offset redirect_lpt1
                dw      offset redirect_lpt2
                dw      offset redirect_lpt1_lpt2
                dw      offset redirect_lpt3
                dw      offset redirect_lpt1_lpt3
                dw      offset redirect_lpt2_lpt3
                dw      offset redirect_all_printers

redirect_no_printers:
                mov     word ptr es:[resident_printer_branch],0EBh
                jmp     short printer_patch_ret

redirect_lpt1:
                mov     word ptr es:[printer_test_patch],7403h
                jmp     short printer_patch_ret

redirect_lpt2:
                mov     word ptr es:[printer_test_patch],7501h
                jmp     short printer_patch_ret

redirect_lpt1_lpt2:
                mov     word ptr es:[printer_test_patch],7402h
                jmp     short printer_patch_ret

redirect_lpt3:
                mov     word ptr es:[printer_test_patch],7502h
                jmp     short printer_patch_ret

redirect_lpt1_lpt3:
                mov     word ptr es:[printer_test_patch],7401h
                jmp     short printer_patch_ret

redirect_lpt2_lpt3:
                mov     word ptr es:[printer_test_patch],7503h
                jmp     short printer_patch_ret

redirect_all_printers:
                mov     word ptr es:[printer_test_patch],0EB00h

printer_patch_ret:
                ret
                db      0h,0h,0h,0h

decimal_hundreds         label   byte
                db      "d"

decimal_tens             label   byte
                db      0Ah

; ------------------------------------------------------------------------
; DS:BP points to up to three decimal digits. Return the value in BL.
; ------------------------------------------------------------------------

parse_decimal:
                mov     bl,0h
                cmp     byte ptr ds:[bp+2h],0h
                jz      parse_decimal_tens
                mov     al,ds:[bp+0h]
                sub     al,30h
                mul     byte ptr ds:[decimal_hundreds]
                add     bl,al
                inc     bp

parse_decimal_tens:
                mov     al,ds:[bp+0h]
                sub     al,30h
                mul     byte ptr ds:[decimal_tens]
                add     bl,al
                inc     bp
                mov     al,ds:[bp+0h]
                sub     al,30h
                add     bl,al
                ret
                db      0h,0h

msg_resident_loaded      label   byte
                db      0Dh,0Ah
                db      "Resident portion of MODE loaded"
                db      0Dh,0Ah
                db      "$"

; ------------------------------------------------------------------------
; Copy 74h bytes of handler templates to 0000:0580; hook INT 14h and INT
; 17h.
; ------------------------------------------------------------------------

; Detect a prior install by its first instruction. Save the old vectors
; before copying the 74h-byte template.
install_resident:
                push    es
                mov     ax,0h
                mov     es,ax
                mov     di,580h
                mov     ax,word ptr ds:[serial_handler_template]
                cmp     ax,es:[di]
; Leave installed vectors and user settings intact on subsequent
; invocations.
                jz      install_resident_ret
                mov     ax,es:[int14_vector_offset]
                mov     ds:[saved_int14_jump_offset],ax
                mov     ax,es:[int14_vector_segment]
                mov     ds:[saved_int14_jump_segment],ax
                mov     ax,es:[int17_vector_offset]
                mov     ds:[saved_int17_jump_offset],ax
                mov     ax,es:[int17_vector_segment]
                mov     ds:[saved_int17_jump_segment],ax
                mov     si,offset serial_handler_template
                mov     cx,74h
                nop
                rep     movsb
; Update offset/segment pairs atomically with interrupts disabled.
                cli
                mov     ax,580h
                mov     es:[int14_vector_offset],ax
                mov     ax,0h
                mov     es:[int14_vector_segment],ax
                mov     ax,5C0h
                mov     es:[int17_vector_offset],ax
                mov     ax,0h
                mov     es:[int17_vector_segment],ax
                sti
                mov     dx,offset msg_resident_loaded
                mov     ah,9h
                int     21h

install_resident_ret:
                pop     es
                ret

; ------------------------------------------------------------------------
; INT 14h template copied to 0000:0580. Far operands are patched before
; copying.
; ------------------------------------------------------------------------

serial_handler_template:
                test    dl,1h
                jmp     short chain_original_serial

; This literal far-jump operand is replaced with the previous INT 14h vector
; before installation.
chain_original_serial:
                jmp_far 0F000h, 0E739h

; Clear the BIOS Ctrl-Break flag before each attempt so the user can escape
; persistent retries.
serial_retry_loop:
                push    ax
                push    ds
                push    ax
                sub     ax,ax
                mov     ds,ax
                and     byte ptr ds:[bios_ctrl_break_flag],7Fh
                pop     ax
                pop     ds
                pushf
; The installer rewrites this far CALL to chain to the original BIOS serial
; handler.
                call_far 0F000h, 0E739h
                push    ax
                push    ds
                sub     ax,ax
                mov     ds,ax
                test    byte ptr ds:[bios_ctrl_break_flag],80h
                pop     ds
                pop     ax
; Ctrl-Break forces a timeout result instead of retrying forever.
                jz      check_serial_timeout
                or      ah,80h

; Discard the saved original AX before IRET; the BIOS result in AX is
; returned to the caller.
serial_handler_return:
                inc     sp
                inc     sp
                iret

check_serial_timeout:
                test    ah,80h
; Retry only timeout results; successful serial operations return
; immediately.
                jz      serial_handler_return
                pop     ax
                jmp     short serial_retry_loop
                db      0h,0h,0h,0h,0h

; ------------------------------------------------------------------------
; INT 17h template copied to 0000:05C0. Redirect output through BIOS INT
; 14h.
; ------------------------------------------------------------------------

printer_handler_template:
                test    dl,1h
                jmp     short chain_original_printer

; The previous INT 17h vector remains the fallback for printers not selected
; for redirection.
chain_original_printer:
                jmp_far 0F000h, 0EFD2h
                cmp     ah,0h
                jz      send_redirected_character
                mov     ah,80h
                iret

; Translate the LPT number through the resident table, then send the byte
; with BIOS INT 14h.
send_redirected_character:
                push    bx
                push    ax
                push    dx
                mov     ah,1h
; This is a resident per-LPT COM-number table, not the transient dispatch
; table.
                mov     bx,resident_com_by_lpt
                add     bx,dx
                mov     dl,cs:[bx]
                int     14h
                pop     dx
                test    ah,80h
                mov     ah,10h
                jz      return_printer_status
                mov     ah,9h

; Map serial timeout into printer status while returning the original
; character in AL.
return_printer_status:
                pop     bx
                mov     al,bl
                pop     bx
                iret
                db      0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h,0h
                db      0h,0h,0h

msg_illegal_device       label   byte
                db      0Dh,0Ah
                db      "Illegal device name"
                db      7h,0Dh,0Ah
                db      "$"

msg_printer_error        label   byte
                db      0Dh,0Ah
                db      "Printer error"
                db      7h,0Dh,0Ah
                db      "$"

msg_width_80             label   byte
                db      0Dh,0Ah
                db      "LPT"

width_80_lpt_digit       label   byte
                db      " : set for 80"
                db      0Dh,0Ah
                db      "$"

msg_width_132            label   byte
                db      0Dh,0Ah
                db      "LPT"

width_132_lpt_digit      label   byte
                db      " : set for 132"
                db      0Dh,0Ah
                db      "$"

msg_line_spacing         label   byte
                db      0Dh,0Ah
                db      "Printer lines per inch set"
                db      0Dh,0Ah
                db      "$"

printer_number           label   word
                dw      0

; ------------------------------------------------------------------------
; AX=printer byte/function. Use BIOS INT 17h and report printer errors.
; ------------------------------------------------------------------------

send_printer_byte:
                mov     dx,word ptr ds:[printer_number]
                int     17h
                and     ah,0A9h
                cmp     ah,0h
                jz      send_printer_byte_ret
                mov     dx,offset msg_printer_error
                mov     ah,9h
                int     21h

send_printer_byte_ret:
                ret

; ------------------------------------------------------------------------
; Parse LPT configuration: redirection, width (80/132), and line spacing
; (6/8).
; ------------------------------------------------------------------------

set_printer_mode:
                cmp     byte ptr ds:[device_colon],3Ah
                jz      check_redirection_syntax
                jmpn    invalid_printer_name

check_redirection_syntax:
                cmp     byte ptr ds:[device_argument],3Dh
                jnz     configure_physical_printer
                call    redirect_printer
                jmpn    printer_command_done

configure_physical_printer:
                call    unredirect_printer
                cmp     ah,0h
                jnz     parse_printer_width
                jmpn    printer_command_done

; Printer output uses control bytes: width is selected after CAN, spacing
; after ESC.
parse_printer_width:
                mov     bp,offset device_argument
                mov     al,ds:[device_number]
                mov     ds:[width_80_lpt_digit],al
                mov     ds:[width_132_lpt_digit],al
                sub     al,31h
                mov     ah,0h
                mov     word ptr ds:[printer_number],ax
                call    parse_decimal
                cmp     bl,50h
                jnz     check_132_columns
                mov     dx,offset msg_width_80
                mov     ah,9h
                int     21h
                mov     bl,12h
                jmp     short send_width_command

check_132_columns:
                cmp     bl,84h
                jnz     no_width_command
                mov     dx,offset msg_width_132
                mov     ah,9h
                int     21h
                mov     bl,0Fh
                jmp     short send_width_command

no_width_command:
                mov     bl,0h

send_width_command:
                cmp     bl,0h
                jz      parse_line_spacing
                mov     ax,18h
                call    send_printer_byte
                mov     ah,0h
                mov     al,bl
                call    send_printer_byte

parse_line_spacing:
                mov     bl,0h
                cmp     byte ptr ds:[second_argument],0h
                jz      send_spacing_command
                cmp     byte ptr ds:[second_argument],36h
                jnz     check_eight_lines
                mov     bl,32h
                jmp     short send_spacing_command

check_eight_lines:
                cmp     byte ptr ds:[second_argument],38h
                jnz     send_spacing_command
                mov     bl,30h

send_spacing_command:
                cmp     bl,0h
                jz      printer_command_done
                mov     ax,1Bh
                call    send_printer_byte
                mov     ah,0h
                mov     al,bl
                call    send_printer_byte
                mov     dx,offset msg_line_spacing
                mov     ah,9h
                int     21h

printer_command_done:
                jmp     short printer_mode_ret

invalid_printer_name:
                mov     dx,offset msg_illegal_device
                mov     ah,9h
                int     21h

printer_mode_ret:
                ret
                db      0h,0h,0h,0h,0h,0h

baud_rate_table          label   byte
                db      "1115306012244896"

msg_invalid_baud         label   byte
                db      0Dh,0Ah
                db      "Invalid baud rate specified"
                db      7h,0Dh,0Ah
                db      "$"

msg_serial_settings      label   byte
                db      0Dh,0Ah
                db      "COM"

serial_port_digit        label   byte
                db      " : "

baud_text                label   byte
                db      "  "

baud_suffix_chars        label   byte
                db      "  ,"

parity_text              label   byte
                db      "e,"

data_bits_text           label   byte
                db      "7,"

stop_bits_text           label   byte
                db      "1,"

retry_text               label   byte
                db      " "
                db      0Dh,0Ah
                db      "$"

; ------------------------------------------------------------------------
; Copy a comma-separated serial setting; lowercase letters and discard
; spaces.
; ------------------------------------------------------------------------

parse_serial_field:
                or      cx,cx
                jz      parse_serial_field_ret

scan_serial_field:
                mov     al,es:[bx]
                inc     bx
                cmp     al,2Ch
                jz      parse_serial_field_ret
                cmp     al,20h
                jz      advance_serial_field
                cmp     dx,0h
                jz      advance_serial_field
                or      al,20h
                mov     ds:[bp+0h],al
                dec     dx
                inc     bp

advance_serial_field:
                loop    scan_serial_field

parse_serial_field_ret:
                ret

; ------------------------------------------------------------------------
; Set/clear the persistent retry flag and patch the resident INT 14h
; dispatch.
; ------------------------------------------------------------------------

set_serial_retry:
                push    es
                mov     ax,0h
                mov     es,ax
                mov     al,ds:[serial_port_digit]
                and     al,3h
                mov     dl,es:[resident_retry_mask]
                cmp     byte ptr ds:[retry_text],70h
                jnz     disable_serial_retry
                or      dl,al
                jmp     short patch_serial_retry_mask

disable_serial_retry:
                mov     byte ptr ds:[retry_text],2Dh
                xor     al,0FFh
                and     dl,al

; Patch the resident port test to bypass retries for ports whose mask bits
; are clear.
patch_serial_retry_mask:
                mov     es:[resident_retry_mask],dl
                cmp     dl,3h
                jnz     retry_mask_com2
                mov     word ptr es:[resident_serial_branch],5EBh
                jmp     short serial_retry_ret

retry_mask_com2:
                cmp     dl,2h
                jnz     retry_mask_com1
                mov     word ptr es:[resident_serial_branch],575h
                jmp     short serial_retry_ret

retry_mask_com1:
                cmp     dl,1h
                jnz     retry_mask_none
                mov     word ptr es:[resident_serial_branch],574h
                jmp     short serial_retry_ret

retry_mask_none:
                mov     word ptr es:[resident_serial_branch],0EBh

serial_retry_ret:
                pop     es
                ret

; ------------------------------------------------------------------------
; Select baud/parity/data/stop settings, call BIOS INT 14h, and print
; configuration.
; ------------------------------------------------------------------------

; The table holds the first two decimal digits of each supported baud rate,
; in BIOS encoding order.
configure_serial:
                mov     dx,word ptr ds:[baud_text]
                mov     bx,offset baud_rate_table
                mov     si,0h
                mov     cx,8h

find_baud_rate:
                cmp     dx,[bx+si]
                jnz     next_baud_rate
                mov     ax,si
                mov     word ptr ds:[baud_suffix_chars],3030h
                test    ax,8h
                jnz     encode_baud_rate
                mov     word ptr ds:[baud_suffix_chars],2030h

; SI advances by two bytes per rate; shifting it four places puts the rate
; index in AL bits 7..5.
encode_baud_rate:
                mov     cl,4h
; Form the BIOS baud-rate bits from the matched table position.
                shl     al,cl
                cmp     byte ptr ds:[parity_text],6Eh
                jnz     check_odd_parity
                jmp     short encode_stop_bits

check_odd_parity:
                cmp     byte ptr ds:[parity_text],6Fh
                jnz     use_even_parity
                or      al,8h
                jmp     short encode_stop_bits

use_even_parity:
                mov     byte ptr ds:[parity_text],65h
                or      al,18h

encode_stop_bits:
                cmp     byte ptr ds:[stop_bits_text],32h
                jnz     use_one_stop_bit
                or      al,4h
                jmp     short encode_data_bits

use_one_stop_bit:
                mov     byte ptr ds:[stop_bits_text],31h

encode_data_bits:
                cmp     byte ptr ds:[data_bits_text],38h
                jnz     use_seven_data_bits
                or      al,3h
                jmp     short select_serial_port

use_seven_data_bits:
                mov     byte ptr ds:[data_bits_text],37h
                or      al,2h

select_serial_port:
                cmp     byte ptr ds:[serial_port_digit],32h
                jnz     select_com1
                mov     dx,1h
                jmp     short initialize_serial_port

select_com1:
                mov     byte ptr ds:[serial_port_digit],31h
                mov     dx,0h

initialize_serial_port:
                int     14h
                call    set_serial_retry
                mov     dx,offset msg_serial_settings
                mov     ah,9h
                int     21h
                jmp     short configure_serial_ret

next_baud_rate:
                inc     si
                inc     si
                loop    find_baud_rate
                mov     dx,offset msg_invalid_baud
                mov     ah,9h
                int     21h

configure_serial_ret:
                ret

; ------------------------------------------------------------------------
; Validate COM1/COM2 and parse baud, parity, data bits, stop bits, and retry
; option.
; ------------------------------------------------------------------------

set_serial_mode:
                cmp     byte ptr ds:[device_colon],3Ah
                jnz     reject_serial_device
                cmp     byte ptr ds:[device_number],31h
                jz      parse_serial_options
                cmp     byte ptr ds:[device_number],32h
                jz      parse_serial_options

reject_serial_device:
                jmpn    invalid_serial_name

; Default to even parity, seven data bits and one stop bit; 110 baud
; defaults to two stop bits.
parse_serial_options:
                call    install_resident
                mov     al,ds:[device_number]
                mov     ds:[serial_port_digit],al
                mov     si,0h
                mov     bx,command_tail

skip_serial_leading_spaces:
                cmp     byte ptr [bx+si],20h
                jnz     find_serial_option_fields
                inc     si
                jmp     short skip_serial_leading_spaces

find_serial_option_fields:
                lea     bx,[si+86h]
                mov     cl,es:[command_length]
                mov     ch,0h
                cmp     cx,7h
                jl      invalid_serial_parameters
                sub     cx,5h
                mov     bp,offset baud_text
                mov     dx,4h
                call    parse_serial_field
                mov     byte ptr ds:[stop_bits_text],31h
                mov     byte ptr ds:[parity_text],65h
                mov     byte ptr ds:[data_bits_text],37h
                mov     byte ptr ds:[retry_text],20h
                mov     ax,word ptr ds:[baud_text]
                cmp     ax,3131h
                jnz     parse_remaining_serial_options
; The original special case supplies two stop bits at 110 baud.
                mov     byte ptr ds:[stop_bits_text],32h

parse_remaining_serial_options:
                mov     bp,offset parity_text
                mov     dx,1h
                call    parse_serial_field
                mov     bp,offset data_bits_text
                mov     dx,1h
                call    parse_serial_field
                mov     bp,offset stop_bits_text
                mov     dx,1h
                call    parse_serial_field
                mov     bp,offset retry_text
                mov     dx,1h
                call    parse_serial_field
                call    configure_serial
                jmp     short serial_command_done

invalid_serial_parameters:
                mov     dx,offset msg_invalid_parameters
                mov     ah,9h
                int     21h

serial_command_done:
                jmp     short serial_mode_ret

invalid_serial_name:
                mov     dx,offset msg_illegal_device
                mov     ah,9h
                int     21h

serial_mode_ret:
                ret

program         ends
                end     start
