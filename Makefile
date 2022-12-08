all: xibmcmdx.com xibmcmd.com \
     xibmdos.com xasm.com xhex2bin.com xtrans.com xhello.com xibmbio.com \
     xmem.com pcdos.img

xibmbio.com: xibmbio.exe
	echo 60|emu2 bin/exe2bin.exe xibmbio.exe xibmbio.com

xibmbio.exe: xibmbio.obj
	emu2 bin/link.exe xibmbio,xibmbio,xibmbio,xibmbio,

xibmbio.obj: ibmbio.asm 
	emu2 bin/masm.exe ibmbio,xibmbio,xibmbio,xibmbio || rm -f ibmbio.obj

xibmdos.com: xibmdos.exe
	emu2 bin/exe2bin.exe xibmdos.exe xibmdos.com

xibmdos.exe: xibmdos.obj
	emu2 bin/link.exe xibmdos,xibmdos,xibmdos,xibmdos,

xibmdos.obj: ibmdos.asm msdos.asm
	emu2 bin/masm.exe ibmdos,xibmdos,xibmdos,xibmdos || rm -f ibmdos.obj

pcdos.img: xibmcmdx.com xibmbio.com xibmdos.com xasm.com xhello.com xtrans.com \
    xhex2bin.com images/blank.img xmem.com hello.asm hello.bas mkhello.bat
	cp images/blank.img pcdos.img
	mcopy  -p -i pcdos.img xibmbio.com ::IBMBIO.COM
	mcopy  -p -i pcdos.img xibmdos.com ::IBMDOS.COM
	mcopy  -i pcdos.img xibmcmdx.com ::COMMAND.COM
	mcopy  -i pcdos.img bin/masm.exe ::MASM.EXE
	mcopy  -i pcdos.img bin/link.exe ::LINK.EXE
	mcopy  -i pcdos.img bin/lib.exe ::LIB.EXE
	mcopy  -i pcdos.img bin/basic.com ::BASIC.COM
	mcopy  -i pcdos.img bin/basica.com ::BASICA.COM
	mcopy  -i pcdos.img bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i pcdos.img bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i pcdos.img bin/sys.com ::SYS.COM
	mcopy  -i pcdos.img bin/edlin.com ::EDLIN.COM
	mcopy  -i pcdos.img bin/format.com ::FORMAT.COM
	mcopy  -i pcdos.img bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i pcdos.img bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i pcdos.img bin/comp.com ::COMP.COM
	mcopy  -i pcdos.img bin/debug.com ::DEBUG.COM
	mcopy  -i pcdos.img bin/mode.com ::MODE.COM
	mcopy  -i pcdos.img xasm.com ::ASM.COM
	mcopy  -i pcdos.img xtrans.com ::TRANS.COM
	mcopy  -i pcdos.img xhello.com ::HELLO.COM
	mcopy  -i pcdos.img xhex2bin.com ::HEX2BIN.COM
	mcopy  -i pcdos.img hello.asm ::HELLO.ASM
	mcopy  -i pcdos.img mkhello.bat ::MKHELLO.BAT
	mcopy  -i pcdos.img hello.bas ::HELLO.BAS
	mcopy  -i pcdos.img xmem.com ::MEM.COM
	[ -f private/pceexit.com ] && mcopy  -i pcdos.img private/pceexit.com ::EXIT.COM
	mattrib -i pcdos.img -a ::"*.*"
	mattrib -i pcdos.img +h +s ::IBMDOS.COM
	mattrib -i pcdos.img +h +s ::IBMBIO.COM
	mdir -w -i pcdos.img ::

xibmcmd.com: xibmcmd.exe 
	emu2 bin/exe2bin.exe xibmcmd.exe xibmcmd.com

xibmcmd.exe: xibmcmd.obj
	emu2 bin/link.exe xibmcmd,xibmcmd,xibmcmd,xibmcmd,

xibmcmd.obj: ibmcmd.asm
	emu2 bin/masm.exe ibmcmd,xibmcmd,xibmcmd,xibmcmd  || rm -f xibmcmdx.obj

xibmcmdx.com: xibmcmdx.exe
	emu2 bin/exe2bin.exe xibmcmdx.exe xibmcmdx.com

xibmcmdx.exe: xibmcmdx.obj
	emu2 bin/link.exe xibmcmdx,xibmcmdx,xibmcmdx,xibmcmdx, 

xibmcmdx.obj: ibmcmdx.asm
	emu2 bin/masm.exe ibmcmdx,xibmcmdx,xibmcmdx,ibmcmdx || rm -f xibmcmdx.obj

xmem.com: xmem.exe
	emu2 bin/exe2bin.exe xmem.exe xmem.com

xmem.exe: xmem.obj
	emu2 bin/link.exe xmem,xmem,xmem,xmem, 

xmem.obj: mem.asm
	emu2 bin/masm.exe mem,xmem,xmem,mem || rm -f xmem.obj

xhello.com: hello.asm xasm.com xhex2bin.com
	emu2 xasm.com hello.ccz
	emu2 xhex2bin.com hello
	mv hello.com xhello.com

xtrans.com: trans.asm xasm.com xhex2bin.com
	emu2 xasm.com trans.ccz
	emu2 xhex2bin.com trans
	mv trans.com xtrans.com

xasm.com: asm.asm
	emu2 bin/asm.com asm.ccz
	emu2 bin/hex2bin.com asm
	mv asm.com xasm.com

xhex2bin.com: hex2bin.asm
	emu2 bin/asm.com hex2bin.ccz
	emu2 bin/hex2bin.com hex2bin
	mv hex2bin.com xhex2bin.com

clean:
	rm -f xibmdos.exe ibmdos.obj xibmdos.com
	rm -f xibmbio.exe ibmbio.obj xibmbio.com
	rm -f xibmcmd.exe ibmcmd.obj xibmcmd.com
	rm -f xibmcmdx.exe ibmcmdx.obj xibmcmdx.com
	rm -f xasm.com xhex2bin.com xtrans.com xhello.com xmem.com
	rm -f *.crf *.err *.lst *.map *.hex *.prn *.HEX *.PRN
	rm -f *.log
	rm -f pcdos.img
