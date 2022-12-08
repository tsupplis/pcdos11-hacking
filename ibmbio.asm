DOS_SEG SEGMENT AT 0BFH
MSDOS   LABEL   FAR
DOS_SEG ENDS

;BIOSSEG SEGMENT AT 60H
BIOSSEG SEGMENT

DOSSIZE 	EQU     2000H

	ASSUME  CS:BIOSSEG

	JMP     NEAR PTR INIT
	JMP     NEAR PTR STATUS ; Will be JMP SHORT + NOP
	JMP     NEAR PTR CONIN
	JMP     NEAR PTR CONOUT
	JMP     NEAR PTR PRINT
	JMP     NEAR PTR AUXIN
	JMP     NEAR PTR AUXOUT
	JMP     NEAR PTR READ
	JMP     NEAR PTR WRITE
	JMP     NEAR PTR DSKCHG
	JMP     NEAR PTR SETDATE
	JMP     NEAR PTR SETTIME
	JMP     NEAR PTR GETTIME
	JMP     NEAR PTR FLUSH
	JMP     NEAR PTR MAPDEV

MSGOOP  DB 13,10,'Out of paper',13,10,0
MSGPRFL DB 13,10,'Printer fault',13,10,0
MSGAIOE DB 13,10,'Aux I/O error',13,10,0


STATUS  PROC    FAR
	MOV     AL,CS:[LASTCHR] ; Returns pending character in AL and ZF clear
	OR      AL,AL   	; Or ZF set and zero in AL
	JNZ     STDONE
	PUSH    DX
	XCHG    AX,DX   	; Save AX in DX
	MOV     AH,1
	INT     16H     	; KBD: CHECK BUFFER
				; Returns ZF clear if char in buffer,
				;  otherwise ZF set
				; Returns scan code in AH, ASCII char in AL
	JZ      RESTORAH
	CMP     AX,7200H	; Ctrl+PrtSc?
	JNZ     RESTORAH
	MOV     AL,10H  	; Translate to Ctrl+P
	OR      AL,AL
RESTORAH:
	MOV     AH,DH   	; Restore saved AH
	POP     DX
STDONE:
	RET
STATUS  ENDP

BREAK:
	MOV     CS:[LASTCHR],3  ; Not using BYTE PTR produces NOP
;        NOP
IRETINS:
	IRET

INAGAIN:
	XCHG    AX,DX   	; Restore AX
	POP     DX      	; Restore DX

CONIN   PROC    FAR
	MOV     AL,0
	XCHG    AL,CS:[LASTCHR]
	OR      AL,AL   	; Is there a char already waiting?
	JNZ     HAVECHR
	PUSH    DX
	XCHG    AX,DX   	; Save AX in DX
	MOV     AH,0
	INT     16H     	; KBD: READ CHAR FROM BUFFER, WAIT IF EMPTY
				; Returns scan code in AH, ASCII char in AL
	OR      AX,AX
	JZ      INAGAIN
	CMP     AX,7200H	; Ctrl+PrtSc?
	JNZ     NOXLAT
	MOV     AL,10H  	; Translate to Ctrl+P
NOXLAT:
	CMP     AL,0
	JNZ     GOTCHAR
	MOV     CS:[LASTCHR],AH
GOTCHAR:
	MOV     AH,DH   	; Restore AH
	POP     DX
HAVECHR:
	RET
CONIN   ENDP

CONOUT  PROC    FAR
	PUSH    BP
	PUSH    AX
	PUSH    BX
	PUSH    SI
	PUSH    DI
	MOV     AH,0EH
	MOV     BX,7
	INT     10H     	; VIDEO: WRITE TTY
				; Input: AL = character, BH = page
	POP     DI
	POP     SI
	POP     BX
	POP     AX
	POP     BP
	RET
CONOUT  ENDP

PRINT   PROC    FAR
	PUSH    AX
	PUSH    DX
	MOV     CS:[PRTFLAG],0  ; not using BYTE PTR produces NOP
;        NOP
NXTPRCH:
	MOV     DX,0
	MOV     AH,0
	INT     17H     	; PRINTER: WRITE CHARACTER
				; Input:  AL = character, DX = port
				; Output: AH = status bits
	MOV     DX,OFFSET MSGOOP
	TEST    AH,20H
	JNZ     ERROUT
	MOV     DX,OFFSET MSGPRFL
	TEST    AH,5
	JZ      POPRET
	XOR     CS:[PRTFLAG],1  ; Not using BYTE PTR produces NOP
;        NOP
	JNZ     NXTPRCH
ERROUT:
	CALL    CONSTR
POPRET:
	POP     DX
	POP     AX
	RET
PRINT   ENDP

CONSTR:
	XCHG    SI,DX
NEXTCS:
	LODS    BYTE PTR CS:[SI]
	AND     AL,7FH
	JZ      CSDONE
	CALL    CONOUT
	JMP     SHORT NEXTCS
CSDONE:
	XCHG    SI,DX
	RET

AUXIN   PROC    FAR
	PUSH    DX
	PUSH    AX
	MOV     DX,0
	MOV     AH,2
	INT     14H     	; SERIAL: RECEIVE CHARACTER
				; Input:  DX = port number
				; Output: AL = character, AH = status
	MOV     DX,OFFSET MSGAIOE
	TEST    AH,0EH
	JZ      AINDONE
	CALL    CONSTR
AINDONE:
	POP     DX
	MOV     AH,DH
	POP     DX
	RET
AUXIN   ENDP

AUXOUT:
	PUSH    AX
	PUSH    DX
	MOV     AH,1
	MOV     DX,0
	INT     14H     	; SERIAL: TRANSMIT CHARACTER
				; Input:  AL = character, DX = port number
				; Output: AH = RS-232 status, AL = modem status
	TEST    AH,80H
	JZ      POPRET
	MOV     DX,OFFSET MSGAIOE
	JMP     SHORT ERROUT

DSKCHG  PROC    FAR
	SHL     AL,1    	; AH must be zero on input and is unchanged to indicate
				; that disk status is unknown.
				; AL is disk driver number on input and I/O driver on output
	RET
DSKCHG  ENDP

SETDATE PROC    FAR
	MOV     CS:[DAYS],AX    ; Number of days since Jan 1, 1980
	XOR     AX,AX   	; Init midnight rollover counter
	INT     1AH     	; Get time of day (clock count in CX:DX)
	RET
SETDATE ENDP

SETTIME PROC    FAR
	MOV     AL,60
	MUL     CH      	; CH = hours
	MOV     CH,0
	ADD     AX,CX   	; CL = minutes
	MOV     CX,6000
	MOV     BX,DX
	MUL     CX
	MOV     CX,AX
	MOV     AL,100
	MUL     BH
	ADD     CX,AX
	ADC     DX,0
	MOV     BH,0
	ADD     CX,BX
	ADC     DX,0
	XCHG    AX,DX
	XCHG    AX,CX
	MOV     BX,59659
	MUL     BX
	XCHG    DX,CX
	XCHG    AX,DX
	MUL     BX
	ADD     AX,CX
	ADC     DX,0
	XCHG    AX,DX
	MOV     BX,5
	DIV     BL
	MOV     CL,AL
	MOV     CH,0
	MOV     AL,AH
	CBW
	XCHG    AX,DX
	DIV     BX
	MOV     DX,AX
	MOV     AH,1
	INT     1AH     	; SET TIME OF DAY, clock count in CX:DX
	RET
SETTIME ENDP

GETTIME PROC    FAR
	PUSH    BX
	MOV     AX,0
	INT     1AH     	; GET TIME OF DAY, clock count in CX:DX
				; AL nonzero if midnight rollover occurred
	ADD     CS:[DAYS],AX
	MOV     AX,CX
	MOV     BX,DX
	SHL     DX,1
	RCL     CX,1
	SHL     DX,1
	RCL     CX,1
	ADD     DX,BX
	ADC     AX,CX
	XCHG    AX,DX
	MOV     CX,59659
	DIV     CX
	MOV     BX,AX
	XOR     AX,AX
	DIV     CX
	MOV     DX,BX
	MOV     CX,200
	DIV     CX
	CMP     DL,100
	JB      NOSUB
	SUB     DL,100
NOSUB:
	CMC
	MOV     BL,DL
	RCL     AX,1
	MOV     DL,0
	RCL     DX,1
	MOV     CX,60
	DIV     CX
	MOV     BH,DL
	DIV     CL
	XCHG    AL,AH
	MOV     DX,BX
	XCHG    CX,AX
	MOV     AX,CS:[DAYS]
	POP     BX
	RET
GETTIME ENDP

FLUSH   PROC    FAR
	MOV     CS:[LASTCHR],0  ; Not using BYTE PTR produces NOP
;        NOP
	PUSH    DS
	XOR     BP,BP
	MOV     DS,BP
	MOV     WORD PTR DS:[41AH],1EH
	MOV     WORD PTR DS:[41CH],1EH
	POP     DS
	RET
FLUSH   ENDP

MAPDEV  PROC    FAR
	AND     AH,1    	; AH contains FAT media ID byte
	OR      AL,AH   	; AL contains I/O driver used to read FAT on input
				; and I/O driver for this disk on output
	RET     		; The FAT media ID byte has 0 in low bit for single-sided
				; and 1 for double-sided disks (FEh vs. FFh)
MAPDEV  ENDP

DMABUF:
INICOM  PROC    FAR
	XOR     DX,DX   	; This area will be later used as a disk buffer (512 bytes)
				; to handle DMA 64K boundary crossing.
	XOR     AX,AX   	; The code depends on the fact that COMMAND.COM will
				; be loaded entirely within the first 64K and the buffer
				; won't be needed until after COMMAND.COM loads
	MOV     SS,AX
	MOV     SP,600H 	; Set stack right below BIOSSEG
	INT     13H     	; DISK: RESET DISK SYSTEM
				; DL = drive (both hard and floppy disks if top bit set)
	MOV     AL,0A3H
	INT     14H     	; SERIAL: INITIALIZE UART
				; Input:  AL = init parameters, DX = port number
				; Output: AH = RS-232 status, AL = modem status
	MOV     AH,1
	INT     17H     	; PRINTER: INITIALIZE
				; Input:  DX = printer port
				; Output: AH = status
	MOV     DS,DX
	MOV     ES,DX
	MOV     AX,60H  	; BIOSSEG
	MOV     DS:[6EH],AX     ; Vector 1Bh
	MOV     WORD PTR DS:[6CH],OFFSET BREAK
	MOV     DI,4    	; INT 1h, Single-step
	MOV     BX,OFFSET IRETINS
	XCHG    AX,BX
	STOSW
	XCHG    AX,BX
	STOSW
	ADD     DI,4    	; INT 3h, breakpoint
	XCHG    AX,BX
	STOSW
	XCHG    AX,BX
	STOSW
	XCHG    AX,BX   	; INT 4h
	STOSW
	XCHG    AX,BX
	STOSW
	MOV     DS:[500H],DX    ; Clear 50:0
	MOV     AX,0BFH 	; Move DOS down to here
	MOV     ES,AX
	MOV     CX,DOSSIZE/2    ; Copy 8K
	CLD
	MOV     AX,0E0H 	; DOS was loaded at E0:0
	MOV     DS,AX
	XOR     DI,DI
	MOV     SI,DI
	REP     MOVSW   	; Move 8K of DOS (6,400 bytes on disk)
	PUSH    CS
	POP     DS
	ASSUME  DS:BIOSSEG
	INT     11H     	; Get equipment bits in AX
	ROL     AL,1
	ROL     AL,1
	AND     AX,3    	; Number of additional floppy drives
	JNZ     HAVDRV
	MOV     BYTE PTR [SNGLDR],1
	INC     AX
HAVDRV:
	INC     AX
	SHL     AL,1
	MOV     SI,OFFSET INITTAB
	MOV     [SI],AL
	INT     12H     	; Memory size in 1K units to AX
	MOV     CL,6
	SHL     AX,CL   	; Convert to paragraphs
	XCHG    AX,DX   	; DX contains number of paragraphs of memory total
	CALL    FAR PTR MSDOS   ; DOS INIT
	STI
	XOR     AX,AX
	MOV     ES,AX
	MOV     DI,94H  	; INT 25h
	MOV     AX,OFFSET ABSREAD
	STOSW
	MOV     AX,CS
	STOSW
	MOV     AX,OFFSET ABSWRIT
	STOSW
	MOV     ES:[DI],CS
	MOV     DX,100H
	MOV     AH,1AH
	INT     21H     	; SET DTA ADDRESS to DS:DX
	MOV     CX,DS:[6]       ; Get top of segment
	SUB     CX,100H 	; Subtract PSP size
	MOV     BX,DS
	PUSH    CS
	POP     DS
	ASSUME  DS:BIOSSEG
	MOV     DX,OFFSET FCB
	MOV     AH,0FH
	INT     21H     	; OPEN DISK FILE with FCB in DS:DX
				; Output: AL = 0 if found, -1 if not found
	OR      AL,AL
	JNZ     COMERR
	MOV     WORD PTR [FCB+14],1; Byte size records
	MOV     AH,27H
	INT     21H     	; RANDOM BLOCK READ with FCB in DS:DX
				; CX = number of records to read
	JCXZ    COMERR  	; Read any records?
	CMP     AL,1    	; 1 = EOF reached, no partial record at end
	JNZ     COMERR
	MOV     DS,BX
	MOV     ES,BX
	MOV     SS,BX
	MOV     SP,5CH
	XOR     AX,AX
	PUSH    AX      	; There must be a zero at top of stack for RET to work
	MOV     DX,80H
	MOV     AH,1AH
	INT     21H     	; SET DTA ADDRESS to DS:DX

	PUSH    BX
	MOV     AX,100H
	PUSH    AX
	RET     		; Hop over to COMMAND.COM
INICOM  ENDP

COMERR:
	MOV     DX,OFFSET BADCOM
	CALL    CONSTR
STALL:
	JMP     SHORT STALL

FCB     DB      1       	; Drive A:
	DB      "COMMAND COM"
	DB      25 DUP (0)

BADCOM  DB 13,10
	DB 'Bad or missing Command Interpreter',13,10,0

INITTAB DB      4       	; Number of disk I/O drivers
	DB      0
	DW      DSKSS
	DB      0
	DW      DSKDS
	DB      1
	DW      DSKSS
	DB      1
	DW      DSKDS
	DB      2
	DW      DSKSS
	DB      2
	DW      DSKDS
	DB      3
	DW      DSKSS
	DB      3
	DW      DSKDS
	DB      0
	DW      0

DSKSS   DW      512     	; Sector size
	DB      1       	; Cluster size
	DW      1       	; Reserved sectors
	DB      2       	; FAT count
	DW      64      	; Root dir entries
	DW      320     	; Number of sectors

DSKDS   DW      512     	; Sector size
	DB      2
	DW      1
	DB      2
	DW      112
	DW      640     	; Number of sectors

	ORG     DMABUF + 512    ; Create a 512-byte buffer

DAYS    DW      0
PRTFLAG DB      0
LASTCHR DB      0
	DB      0
DSKOP   DB      2
VFYFLG  DB      0
IODRVN  DB      0
SNGLDR  DB      0
SAVSP   DW      0
NUMSCT  DW      0

ABSREAD PROC    FAR
	SHL     AL,1    	; AL has drive number (A=0, B=1)
READ:
	MOV     AH,2    	; BIOS read subfunction
	JMP     SHORT RWCMD

ZEROXFR:
	CLC
SECOORNG:
	MOV     AL,8    	; Sector not found error
	RET
ABSREAD ENDP

ABSWRIT PROC    FAR
	SHL     AL,1    	; AL has drive number (A=0, B=1)
WRITE:
	MOV     CS:[VFYFLG],AH  ; Stash verify flag
	MOV     AH,3    	; BIOS write subfunction
RWCMD:
	MOV     CS:[IODRVN],AL  ; I/O driver number
	SHR     AL,1
	JCXZ    ZEROXFR 	; CX has number of sectors to transfer
	MOV     SI,DX   	; DX has logical sector number
	ADD     SI,CX
	CMP     SI,641  	; Can't have more than 640 sectors (320K)
	CMC
	JB      SECOORNG
	PUSH    ES
	PUSH    DS
	PUSH    DS
	POP     ES
	PUSH    CS
	POP     DS
	MOV     [SAVSP],SP
	MOV     [DSKOP],AH
	CMP     BYTE PTR [SNGLDR],1
	JNZ     TWODRV
	PUSH    DS
	XOR     SI,SI
	MOV     DS,SI
	MOV     AH,AL
	XCHG    AH,DS:[504H]    ; Single drive status byte (50:04)
	POP     DS
	CMP     AL,AH
	JZ      NOSWAP
	PUSH    DX
	ADD     AL,'A'
	MOV     [MSGCHGD+1CH],AL
	MOV     DX,OFFSET MSGCHGD
	CALL    CONSTR
	CALL    FLUSH
	MOV     AH,0
	INT     16H     	; KBD: READ CHAR FROM BUFFER, WAIT IF EMPTY
				; Returns scan code in AH, ASCII char in AL
	POP     DX
NOSWAP:
	MOV     AL,0
TWODRV:
	XCHG    AX,DX   	; AX now has desired LSN
	MOV     DH,8    	; 8 sectors per track
	DIV     DH
	INC     AH
	MOV     DH,0
	TEST    BYTE PTR [IODRVN],1
	JZ      NODBLS
	SHR     AL,1
	RCL     DH,1
NODBLS:
	XCHG    AL,AH
	XCHG    AX,CX   	; Number of sectors in CX
	MOV     [NUMSCT],AX
	MOV     DI,ES   	; Check for 64K boundary crossing
	SHL     DI,1
	SHL     DI,1
	SHL     DI,1
	SHL     DI,1
	ADD     DI,BX
	ADD     DI,1FFH
	JB      NOCROS
	XCHG    BX,DI
	SHR     BH,1
	MOV     AH,80H
	SUB     AH,BH
	MOV     BX,DI
	CMP     AH,AL
	JBE     NOMORE
	MOV     AH,AL
NOMORE:
	PUSH    AX
	MOV     AL,AH
	CALL    DSKLOOP
	POP     AX
	SUB     AL,AH
	JZ      DSKRET
NOCROS:
	DEC     AL
	PUSH    AX
	CLD
	PUSH    BX
	PUSH    ES
	CMP     BYTE PTR [DSKOP],2     ; Is it  a read?
	JZ      DOREAD
	MOV     SI,BX
	PUSH    CX
	MOV     CX,256
	PUSH    ES
	POP     DS
	PUSH    CS
	POP     ES
	MOV     DI,OFFSET DMABUF
	MOV     BX,DI
	REP     MOVSW
	POP     CX
	PUSH    CS
	POP     DS
	CALL    SCTRWONE
	POP     ES
	POP     BX
	JMP     SHORT MOREIO

DOREAD:
	MOV     BX,OFFSET DMABUF
	PUSH    CS
	POP     ES
	CALL    SCTRWONE
	MOV     SI,BX
	POP     ES
	POP     BX
	MOV     DI,BX
	PUSH    CX
	MOV     CX,256
	REP     MOVSW
	POP     CX
MOREIO:
	ADD     BH,2
	POP     AX
	CALL    DSKLOOP
DSKRET:
	POP     DS
	POP     ES
	CLC
	RET

DSKLOOP:
	OR      AL,AL
	JZ      NOMORSCT
	MOV     AH,9
	SUB     AH,CL
	CMP     AH,AL
	JBE     DL1
	MOV     AH,AL
DL1:
	PUSH    AX
	MOV     AL,AH
	CALL    SECTRW
	POP     AX
	SUB     AL,AH
	SHL     AH,1
	ADD     BH,AH
	JMP     SHORT DSKLOOP

DSKERR:
	XCHG    AX,DI
	MOV     AH,0
	INT     13H     	; DISK - RESET DISK SYSTEM
				; DL = drive (if bit 7 is set both hard disks and floppy disks reset)
	DEC     SI      	; Decrement retry count
	JZ      XLATERR
	MOV     AX,DI
	CMP     AH,80H
	JZ      XLATERR
	POP     AX
	JMP     SHORT DSKRETRY

XLATERR:
	PUSH    CS
	POP     ES
	MOV     AX,DI
	MOV     AL,AH
	MOV     CX,10
	MOV     DI,OFFSET BDSKERR
	REPNE   SCASB
	MOV     AL,[DI+9]
	MOV     CX,[NUMSCT]
	MOV     SP,[SAVSP]
	POP     DS
	POP     ES
	STC
	RET
ABSWRIT ENDP

SCTRWONE:
	MOV     AL,1    	; One sector at a time
SECTRW:
	MOV     SI,5    	; Set retry count
	MOV     AH,[DSKOP]      ; BIOS subfunction (2 or 3)
DSKRETRY:
	PUSH    AX
	CMP     CH,40   	; LSNs are all tracks on side 0 first, then side 1
	JB      DODSK
	SUB     CH,40   	; Subtract 40 from track number
	XOR     DH,1    	; Flip the head number
DODSK:
	INT     13H     	; DISK -
	JB      DSKERR
	POP     AX
	PUSH    AX
	CMP     WORD PTR [DSKOP],103H    ; Is this write with verify?
	jnz     NOVFY
	MOV     AH,4    	; VERIFY SECTORS
	INT     13H     	; AL = number of sectors to verify, CH = track, CL = sector
				; DH = head, DL = drive
				; Return: CF set on error, AH = status
				; AL = number of sectors verified
	JC      DSKERR
NOVFY:
	POP     AX
	MOV     AH,0
	SUB     [NUMSCT],AX
	ADD     CL,AL
	CMP     CL,8    	; Need to go to next track?
NOMORSCT:
	JBE     SCTDONE
	MOV     CL,1
	TEST    BYTE PTR [IODRVN],1
	JZ      NXTTRK
	XOR     DH,1
	JNZ     SCTDONE
NXTTRK:
	INC     CH
SCTDONE:
	RET

MSGCHGD DB 0Dh,0Ah
	DB 'Insert diskette for drive A: and strike',0Dh,0Ah
	DB 'any key when ready',0Dh,0Ah
	DB 0Ah,0

BDSKERR DB  80h
	DB  40h
	DB  20h
	DB  10h
	DB    9
	DB    8
	DB    4
	DB    3
	DB    2
	DB    1
DDSKERR DB    2 		; Not ready
	DB    6 		; Seek error
	DB  0Ch 		; Other disk error
	DB    4 		; Data error
	DB  0Ch 		; Other disk error
	DB    4 		; Data error
	DB    8 		; Sector not found
	DB    0 		; Write protect
	DB  0Ch 		; Other disk error
	DB  0Ch 		; Other disk error

	; The following is likely junk
	db  1Dh
	db  3Ch
	db    0
	db  74h
	db  1Dh
	db  8Ah
	db  0Eh
	db  7Fh
	db  1Dh
	db 0F6h
	db 0D1h
	db 0B4h
	db    0
	db  89h
	db 0C3h
	db  8Ah
	db  87h
	db 0C9h
	db  32h
	db  3Ah
	db    6
	db  72h
	db  1Dh
	db 0B0h
	db 0FFh
	db  77h
	db    1
	db  40h
	db  22h
	db 0C1h
	db 0D0h
	db 0D8h
	db  80h
	db  40h
	db  20h
	db  10h
	db    9
	db    8
	db    4
	db    3
	db    2
	db    1
	db    2
	db    6
	db  0Ch
	db    4
	db  0Ch
	db    4
	db    8
	db    0
	db  0Ch
	db  0Ch
	db  20h 		; Junk duplicated from above?!
	db  72h ; r
	db  65h ; e
	db  61h ; a
	db  64h ; d
	db  79h ; y
	db  0Dh
	db  0Ah
	db  0Ah
	db    0
	db  80h ; €
	db  40h ; @
	db  20h
	db  10h
	db    9
	db    8
	db    4
	db    3
	db    2
	db    1
	db    2
	db    6
	db  0Ch
	db    4
	db  0Ch
	db    4
	db    8
	db    0
	db  0Ch
	db  0Ch

	ORG     650H
INIT:
INITP   PROC    FAR
	PUSH    SI
	PUSH    DI
	PUSH    DS
	PUSH    ES
	PUSH    CX
	PUSH    AX
	XOR     AX,AX
	MOV     ES,AX
	PUSH    CS
	POP     DS
	MOV     SI,OFFSET DPT
	MOV     DI,570H 	; Ends up at 0:570 aka 50:70
	MOV     AX,DI
	MOV     CX,11
	REP     MOVSB
	MOV     DI,1EH*4	; INT 1Eh (DPT)
	STOSW
	XOR     AX,AX
	STOSW
	POP     AX
	POP     CX
	POP     ES
	POP     DS
	POP     DI
	POP     SI
	JMP     NEAR PTR INICOM
INITP   ENDP

DPT     DB      0DFH
	DB      2
	DB      25H
	DB      2
	DB      8
	DB      2AH
	DB      0FFH
	DB      50H
	DB      0F6H
	DB      0
	DB      4

IFDEF   NOEXACT
	JMP     INIT
ELSE
	DB      0E9H    	; Force a near (not short) jump
	DW      INIT-($+2)
ENDIF

	DB      249 DUP (0)

ENDBIOS LABEL   BYTE
BIOSSEG ENDS

; There will be a 'No STACK segment' warning. That appears to be
; unavoidable and harmless. If a stack segment is added, EXE2BIN
; will fail;

	END
