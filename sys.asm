program     segment
            assume cs:program, ds:program
            org 100h

_start:
            jmp short chk_drv
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
            cmp byte ptr ds:[5DH], 20h ; ' '
            jnz invalid_param
            cmp al, 0FFh
            jz invalid_drv
            cmp byte ptr ds:[5CH], 00h ; PSP Drive Defined?
            jz invalid_drv
            mov ah, 19h ; Get default drive
            int 21h
            inc al
            mov byte ptr [default_drv],al
            cmp ds:[5CH], al
            jz invalid_drv
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
            mov al,ds:[5Ch] 
            mov byte ptr [output_fcb],al
            mov byte ptr [input_fcb],al
            mov dl,ds:[5Ch] ; Get PSP drive
            mov ah,1Ch ; Get drive alloc data
            int 21h
            push cs
            pop ds
            mov ah, 00h
            mul cx
            xchg ax,cx
            mov bx, offset input_ctl
            call label_1ef
            jnz incompat_sys
            mov bx, offset output_ctl
            call label_1ef
            ja incompat_sys
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
label_1ef:
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
              db 4 dup (0)
              db 25 dup (0)
buff_start:

program       ends
              end _start
