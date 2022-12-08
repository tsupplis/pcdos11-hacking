all: xibmcmdx.com xibmcmd.com \
     xibmdos.com xasm.com xhex2bin.com xtrans.com xhello.com xibmbio.com \
     xmem.com pcdos_full.img pcdos_base.img

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

pcdos_base.img: xibmcmdx.com xibmbio.com xibmdos.com images/blank.img
	cp images/blank.img $@
	mcopy  -p -i $@ xibmbio.com ::IBMBIO.COM
	mcopy  -p -i $@ xibmdos.com ::IBMDOS.COM
	mcopy  -i $@ xibmcmdx.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::IBMDOS.COM
	mattrib -i $@ +h +s ::IBMBIO.COM
	mdir -w -i $@ ::

pcdos_full.img: pcdos_base.img xasm.com xhello.com xtrans.com \
    xhex2bin.com xmem.com hello.asm hello.bas mkhello.bat
	cp pcdos_base.img $@
	mcopy  -i $@ bin/masm.exe ::MASM.EXE
	mcopy  -i $@ bin/link.exe ::LINK.EXE
	mcopy  -i $@ bin/lib.exe ::LIB.EXE
	mcopy  -i $@ bin/basic.com ::BASIC.COM
	mcopy  -i $@ bin/basica.com ::BASICA.COM
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/sys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/format.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/comp.com ::COMP.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mcopy  -i $@ xasm.com ::ASM.COM
	mcopy  -i $@ xtrans.com ::TRANS.COM
	mcopy  -i $@ xhello.com ::HELLO.COM
	mcopy  -i $@ xhex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ hello.asm ::HELLO.ASM
	mcopy  -i $@ mkhello.bat ::MKHELLO.BAT
	mcopy  -i $@ hello.bas ::HELLO.BAS
	mcopy  -i $@ xmem.com ::MEM.COM
	[ -f private/pceexit.com ] && mcopy  -i $@ private/pceexit.com ::EXIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

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
	rm -f pcdos_*.img
