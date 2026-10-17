;*-------------------------------------------------------------------------
;  SYS.ASM - DOS 1.x system-transfer utility
;
;  Build:   make ibmsys.com       (IBM PC-DOS: IBMBIO.COM, IBMDOS.COM)
;           make mssys.com        (Microsoft MS-DOS: IO.SYS, MSDOS.SYS)
;
;  Usage:   SYS d:
;           Copies the two system files from the current (source) drive to
;           drive d:.  The destination must already contain its system files;
;           SYS overwrites their contents and does not create files.
;
;  Operation:
;     1. Validates the destination drive parsed by DOS into PSP FCB1.
;     2. Reads the source BIOS and DOS files into two 8 KiB buffers.
;     3. Checks that the destination files' pre-existing allocations are
;        compatible with the byte counts read from the source images.
;     4. Writes the BIOS file, then the DOS file, to the destination drive.
;
;  The files are accessed through extended FCBs, not pathnames.  This is why
;  the program can switch from the source drive to the destination by changing
;  only the drive byte in each FCB.  File sizes are handled as 16-bit values,
;  appropriate to the small DOS 1.x system files.
;
;  Variant selection is made by the including wrapper:
;     ibmsys.asm  sets IBMVER and installs IBMBIO.COM / IBMDOS.COM
;     mssys.asm   sets MSVER  and installs IO.SYS / MSDOS.SYS
;
;  Memory (COM image, single segment, org 100h):
;     0000h-00FFh   PSP; FCB1 at 5Ch records the SYS destination drive
;     0100h-...     code, messages, and two extended FCB control blocks
;     buff_start    16 KiB work area: DOS image at +1, BIOS image at +2001h
;-------------------------------------------------------------------------

program     segment
            assume cs:program, ds:program
            org 100h

;-------------------------------------------------------------------------
; PSP fields used by SYS.  DOS parses SYS d: into FCB1 before transferring
; control; a blank name field means that only a drive specification was given.
;-------------------------------------------------------------------------
psp_fcb1        equ 5Ch
psp_fcb1_name   equ psp_fcb1 + 1

_start:
            jmp short chk_drv

;-------------------------------------------------------------------------
; Error exits.  DX is the DOS function 09h '$'-terminated message.
;-------------------------------------------------------------------------
invalid_param:
            mov dx, offset invalid_param_msg
            jmp exit
invalid_drv:
            mov dx, offset invalid_drv_msg
            jmp exit
insert_drv:
            mov al, byte ptr [default_drv]
            add al, 40h ; 'A'
            mov byte ptr [insert_drv_val], al
            mov dx, offset insert_drv_msg
            mov ah, 09h ; Print string
            int 21h
            mov ax, 0C08h ; Read 8-bit character after prompt
            int 21h
            xor al, al
chk_drv:
            cmp byte ptr ds:[psp_fcb1_name], 20h ; Only a drive, not a filename
            jnz invalid_param
            cmp al, 0FFh
            jz invalid_drv
            cmp byte ptr ds:[psp_fcb1], 00h ; PSP destination drive defined?
            jz invalid_drv
            mov ah, 19h ; Get default drive
            int 21h
            inc al
            mov byte ptr [default_drv],al
            cmp ds:[psp_fcb1], al
            jz invalid_drv

;-------------------------------------------------------------------------
; Source files use drive 0 (the current/default drive).  If either cannot be
; opened, ask for a system disk and retry from the beginning.
;-------------------------------------------------------------------------
            mov ah, 0Fh ; FCB Open
            mov dx, offset input_ctl ; FCB for input
            int 21h
            or al,al
            jnz insert_drv
            mov dx, offset output_ctl
            mov ah, 0Fh ; FCB Open
            int 21h
            or al,al
            jnz insert_drv
            mov ah, 1Ah ; Set DTA
            mov dx, offset buff_start + 1 + 2000h
            int 21h

;-------------------------------------------------------------------------
; Use one-byte FCB records, so the random block counts and file-size checks
; below are byte counts.  The BIOS buffer follows the DOS buffer deliberately:
; each read then uses a single contiguous 8 KiB area.
;-------------------------------------------------------------------------
            mov ax, 01h
            mov word ptr [input_fsiz],ax 
            mov word ptr [output_fsiz],ax 
            mov bx, offset input_ctl
            mov cx, 8000h
            call read_file
            mov dx, offset buff_start + 1
            mov ah, 1Ah ; Set DTA
            int 21h
            mov bx, offset output_ctl
            mov cx, 2000h
            call read_file

;-------------------------------------------------------------------------
; Retarget both FCBs to the requested destination drive.  Names and the data
; just read remain unchanged.
;-------------------------------------------------------------------------
            mov al,ds:[psp_fcb1]
            mov byte ptr [output_fcb],al
            mov byte ptr [input_fcb],al
            mov dl,ds:[psp_fcb1] ; Get destination drive allocation data
            mov ah,1Ch ; Get drive alloc data
            int 21h
            push cs
            pop ds
            mov ah, 00h
            mul cx
            xchg ax,cx

;-------------------------------------------------------------------------
; Compare the destination files' existing allocation with the source byte
; counts.  The BIOS file must occupy the same number of clusters; the DOS file
; may be larger, but not smaller.  DOS 1.x SYS therefore transfers into
; system-file placeholders made when the destination disk was formatted; it
; cannot create or extend them.
;-------------------------------------------------------------------------
            mov bx, offset input_ctl
            call check_room
            jnz incompat_sys
            mov bx, offset output_ctl
            call check_room
            ja incompat_sys

;-------------------------------------------------------------------------
; Write the BIOS image first, then the DOS image, using the same FCBs now
; addressed to the destination drive.
;-------------------------------------------------------------------------
            mov dx, offset buff_start + 1 + 2000h
            mov ah, 1Ah ; Set DTA
            int 21h
            mov bx, offset input_ctl
            call write_file
            mov dx, offset buff_start + 1
            mov ah, 1Ah ; Set DTA
            int 21h
            mov bx, offset output_ctl
            call write_file
            mov dx, offset sys_trans_msg
exit:
            mov ah, 09h
            int 21h
            int 20h
no_room:
            mov dx, offset no_room_msg
            jmp short exit
incompat_sys:
            mov dx, offset incompat_sys_size_msg
            jmp short exit
;-------------------------------------------------------------------------
; Read CX one-byte records into the caller-selected DTA.  DOS returns the
; actual record count in CX; preserve it at +30h for the matching write.
; The date and time fields are also saved because the FCB write path alters
; them before the file is closed.
;-------------------------------------------------------------------------
read_file:
            mov ah, 27h ; Random Block Read
            mov dx,bx
            int 21h
            mov [bx+30h],cx
            mov ax,[bx+1Bh]
            mov [bx+2Ch],ax
            mov ax,[bx+1Dh]
            mov [bx+2Eh],ax
            ret

;-------------------------------------------------------------------------
; Check the allocation represented by BX's FCB.
; CX = bytes per cluster.  On return, CMP compares transferred bytes rounded
; up to clusters (AX) with the opened file's size rounded up to clusters (DX).
; The caller chooses equality for the source and "at least" for the target.
;-------------------------------------------------------------------------
check_room:
            mov ah, 0Fh ; FCP Open
            mov dx,bx
            int 21h
            or al,al
            jnz no_room
            mov ax,[bx+17h]
            xor dx,dx
            add ax,cx
            dec ax
            div cx
            push ax
            mov ax,[bx+30h]
            add ax,cx
            dec ax
            xor dx,dx
            div cx
            pop dx
            cmp ax,dx
            ret
;-------------------------------------------------------------------------
; Restart random I/O at record zero, write exactly the byte count recorded by
; read_file, restore the saved timestamp fields, and close the destination.
;-------------------------------------------------------------------------
write_file:
            mov dx,bx
            xor ax,ax
            mov [bx+28h],ax
            mov [bx+2Ah],ax
            inc ax
            mov [bx+15h],ax
            mov ah,28h ; Random block write
            mov cx,[bx+30h]
            int 21h
            mov ax,[bx+2Ch]
            mov [bx+1Bh],ax
            mov ax,[bx+2Eh]
            mov [bx+1Dh],ax
            mov ah,10h ; FCB Close
            int 21h
            ret
; Messages and transfer state.
invalid_drv_msg:
            db 'Invalid drive specification$'
invalid_param_msg:
            db 'Invalid parameter$'
insert_drv_msg:
            db 'Insert system disk in drive '
insert_drv_val:
            db 'A',0Dh,0Ah,'and strike any key when ready',0Dh,0Ah,'$'
no_room_msg:
            db 'No room for system on destination disk$'
incompat_sys_size_msg:
            db 'Incompatible system size$'
sys_trans_msg:
            db 'System transferred$'
default_drv:
            db 00h

;-------------------------------------------------------------------------
; Extended FCBs for the BIOS (input) and DOS (output) files.  The FFh marker
; and six bytes ahead of each ordinary FCB are the DOS extended-FCB prefix.
; Drive zero initially means the current drive; the code replaces it with the
; requested destination drive after both source files have been read.
;-------------------------------------------------------------------------
input_ctl:
              db 0FFh, 00h
              db 00h, 00h, 00h, 00h
              db 06h
input_fcb:
              db 00h 
IF MSVER
              db 'IO      SYS'  
ENDIF
IF IBMVER
              db 'IBMBIO  COM'  
ENDIF
              db 2  dup (0)
input_fsiz:
              ; FCB record size followed by its four-byte file-size field.
              db 4 dup (0)
              db 25 dup (0)
output_ctl:
              db 0FFh, 00h
              db 00h, 00h, 00h, 00h
              db 06h 
output_fcb:
              db 00h 
IF MSVER
              db 'MSDOS   SYS'  
ENDIF
IF IBMVER
              db 'IBMDOS  COM'  
ENDIF
              db 2 dup (0)
output_fsiz:
              ; FCB record size followed by its four-byte file-size field.
              db 4 dup (0)
              db 25 dup (0)

;-------------------------------------------------------------------------
; Uninitialised 16 KiB data-transfer area.  The DTA begins at +1 so the
; buffer has the same odd alignment as the original program.
;-------------------------------------------------------------------------
buff_start:

program       ends
              end _start
