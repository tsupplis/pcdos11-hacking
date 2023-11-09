all: ibmcmd.com ibmdos.com ibmbio.com \
     xmscmd.com \
     asm.com hex2bin.com trans.com hello.com \
     mem.com cls.com \
     pcdos_full.img pcdos_base.img pcdos_dist.img pcdos_diag.img \
     msdos_full.img msdos_base.img msdos_dist.img msdos_diag.img

ibmbio.com: ibmbio.exe
	echo 60|emu2 bin/exe2bin.exe ibmbio.exe ibmbio.com

ibmbio.exe: ibmbio.obj
	emu2 bin/link.exe ibmbio,ibmbio,ibmbio,ibmbio,

ibmbio.obj: ibmbio.asm 
	emu2 bin/masm.exe ibmbio,ibmbio,ibmbio,ibmbio || rm -f ibmbio.obj

ibmdos.com: ibmdos.exe
	emu2 bin/exe2bin.exe ibmdos.exe ibmdos.com

ibmdos.exe: ibmdos.obj
	emu2 bin/link.exe ibmdos,ibmdos,ibmdos,ibmdos,

ibmdos.obj: ibmdos.asm dos.asm
	emu2 bin/masm.exe ibmdos,ibmdos,ibmdos,ibmdos || rm -f ibmdos.obj

msdos_base.img: xmscmd.com ibmbio.com ibmdos.com images/msdos.img
	cp images/msdos.img $@
	mattrib -i $@ -h -s ::MSDOS.SYS
	mattrib -i $@ -h -s ::IO.SYS
	mcopy  -o -p -i $@ ibmbio.com ::IO.SYS
	mcopy  -o -p -i $@ ibmdos.com ::MSDOS.SYS
	mcopy  -o -i $@ xmscmd.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::MSDOS.SYS
	mattrib -i $@ +h +s ::IO.SYS
	mdir -w -i $@ ::

pcdos_base.img: ibmcmd.com ibmbio.com ibmdos.com images/pcdos.img
	cp images/pcdos.img $@
	mattrib -i $@ -h -s ::IBMDOS.COM
	mattrib -i $@ -h -s ::IBMBIO.COM
	mcopy  -o -p -i $@ ibmbio.com ::IBMBIO.COM
	mcopy  -o -p -i $@ ibmdos.com ::IBMDOS.COM
	mcopy  -o -i $@ ibmcmd.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::IBMDOS.COM
	mattrib -i $@ +h +s ::IBMBIO.COM
	mdir -w -i $@ ::

msdos_dist.img: msdos_base.img 
	cp msdos_base.img $@
	mcopy  -i $@ bin/masm.exe ::MASM.EXE
	mcopy  -i $@ bin/mslink.exe ::LINK.EXE
	mcopy  -i $@ bin/lib.exe ::LIB.EXE
	mcopy  -i $@ bin/msbasic.com ::MSBASIC.COM
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/mssys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/msformat.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/filcom.com ::FILCOM.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

msdos_diag.img: msdos_base.img asm.com trans.com \
    hex2bin.com mem.com
	cp msdos_base.img $@
	[ -f private/ext/autoexec.bat ] && mcopy  -i $@ private/ext/autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	[ -f private/ext/pceexit.com ] && mcopy  -i $@ private/ext/pceexit.com ::EXIT.COM
	[ -f private/ext/pceinit.com ] && mcopy  -i $@ private/ext/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

msdos_full.img: msdos_base.img asm.com trans.com \
    hex2bin.com mem.com hello.asm mshello.bas mkhello.bat
	cp msdos_base.img $@
	[ -f private/ext/autoexec.bat ] && mcopy  -i $@ private/ext/autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/masm.exe ::MASM.EXE
	mcopy  -i $@ bin/mslink.exe ::LINK.EXE
	mcopy  -i $@ bin/cref.exe ::CREF.EXE
	mcopy  -i $@ bin/lib.exe ::LIB.EXE
	mcopy  -i $@ bin/msbasic.com ::MSBASIC.COM
	#[ -f private/ext/gwbasic.exe ] && mcopy  -i $@ private/ext/gwbasic.exe ::GWBASIC.EXE
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/mssys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/msformat.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/filcom.com ::FILCOM.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mcopy  -i $@ asm.com ::ASM.COM
	mcopy  -i $@ trans.com ::TRANS.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ hello.asm ::HELLO.ASM
	mcopy  -i $@ mkhello.bat ::MKHELLO.BAT
	mcopy  -i $@ mshello.bas ::HELLO.BAS
	mcopy  -i $@ mem.com ::MEM.COM
	[ -f private/ext/pceexit.com ] && mcopy  -i $@ private/ext/pceexit.com ::EXIT.COM
	[ -f private/ext/pceinit.com ] && mcopy  -i $@ private/ext/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::


pcdos_dist.img: msdos_base.img 
	cp msdos_base.img $@
	mcopy  -i $@ bin/link.exe ::LINK.EXE
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
	[ -f private/ibm/art.bas ] && mcopy  -i $@ private/ibm/art.bas ::ART.BAS
	[ -f private/ibm/ball.bas ] && mcopy  -i $@ private/ibm/ball.bas ::BALL.BAS
	[ -f private/ibm/calendar.bas ] && mcopy  -i $@ private/ibm/calendar.bas ::CALENDAR.BAS
	[ -f private/ibm/circle.bas ] && mcopy  -i $@ private/ibm/circle.bas ::CIRCLE.BAS
	[ -f private/ibm/colorbar.bas ] && mcopy  -i $@ private/ibm/colorbar.bas ::COLORBAR.BAS
	[ -f private/ibm/comm.bas ] && mcopy  -i $@ private/ibm/comm.bas ::COMM.BAS
	[ -f private/ibm/donkey.bas ] && mcopy  -i $@ private/ibm/donkey.bas ::DONKEY.BAS
	[ -f private/ibm/mortgage.bas ] && mcopy  -i $@ private/ibm/mortgage.bas ::MORTGAGE.BAS
	[ -f private/ibm/music.bas ] && mcopy  -i $@ private/ibm/music.bas ::MUSIC.BAS
	[ -f private/ibm/piechart.bas ] && mcopy  -i $@ private/ibm/piechart.bas ::PIECHART.BAS
	[ -f private/ibm/samples.bas ] && mcopy  -i $@ private/ibm/samples.bas ::SAMPLES.BAS
	[ -f private/ibm/space.bas ] && mcopy  -i $@ private/ibm/space.bas ::SPACE.BAS
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

pcdos_diag.img: pcdos_base.img asm.com trans.com \
    hex2bin.com mem.com
	cp pcdos_base.img $@
	[ -f private/ext/autoexec.bat ] && mcopy  -i $@ private/ext/autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	[ -f private/ext/pceexit.com ] && mcopy  -i $@ private/ext/pceexit.com ::EXIT.COM
	[ -f private/ext/pceinit.com ] && mcopy  -i $@ private/ext/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

pcdos_full.img: pcdos_base.img asm.com trans.com \
    hex2bin.com mem.com hello.asm hello.bas mkhello.bat
	cp pcdos_base.img $@
	[ -f private/ext/autoexec.bat ] && mcopy  -i $@ private/ext/autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/masm.exe ::MASM.EXE
	[ -f private/ext/masm.exe ] && mcopy -o -i $@ private/ext/masm.exe ::MASM.EXE
	mcopy  -i $@ bin/link.exe ::LINK.EXE
	[ -f private/ext/link.exe ] && mcopy -o -i $@ private/ext/link.exe ::LINK.EXE
	mcopy  -i $@ bin/cref.exe ::CREF.EXE
	[ -f private/ext/cref.exe ] && mcopy -o -i $@ private/ext/cref.exe ::CREF.EXE
	mcopy  -i $@ bin/lib.exe ::LIB.EXE
	[ -f private/ext/lib.exe ] && mcopy -o -i $@ private/ext/lib.exe ::LIB.EXE
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
	[ -f private/ibm/ball.bas ] && mcopy  -i $@ private/ibm/ball.bas ::BALL.BAS
	mcopy  -i $@ asm.com ::ASM.COM
	mcopy  -i $@ trans.com ::TRANS.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ hello.asm ::HELLO.ASM
	mcopy  -i $@ mkhello.bat ::MKHELLO.BAT
	mcopy  -i $@ hello.bas ::HELLO.BAS
	mcopy  -i $@ mem.com ::MEM.COM
	[ -f private/ext/pceexit.com ] && mcopy  -i $@ private/ext/pceexit.com ::EXIT.COM
	[ -f private/ext/pceinit.com ] && mcopy  -i $@ private/ext/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

xmscmd.com: xmscmd.exe 
	emu2 bin/exe2bin.exe xmscmd.exe xmscmd.com

xmscmd.exe: xmscmd.obj
	emu2 bin/link.exe xmscmd,xmscmd,xmscmd,xmscmd,

xmscmd.obj: mscmd.asm command.asm
	emu2 bin/masm.exe mscmd,xmscmd,xmscmd,xmscmd  || rm -f xmscmd.obj

ibmcmd.com: ibmcmd.exe 
	emu2 bin/exe2bin.exe ibmcmd.exe ibmcmd.com

ibmcmd.exe: ibmcmd.obj
	emu2 bin/link.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd,

ibmcmd.obj: ibmcmd.asm command.asm
	emu2 bin/masm.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd  || rm -f ibmcmd.obj

mem.com: mem.exe
	emu2 bin/exe2bin.exe mem.exe mem.com

mem.exe: mem.obj
	emu2 bin/link.exe mem,mem,mem,mem, 

mem.obj: mem.asm
	emu2 bin/masm.exe mem,mem,mem,mem || rm -f mem.obj

cls.com: cls.exe
	emu2 bin/exe2bin.exe cls.exe cls.com

cls.exe: cls.obj
	emu2 bin/link.exe cls,cls,cls,cls, 

cls.obj: cls.asm
	emu2 bin/masm.exe cls,cls,cls,cls || rm -f cls.obj

hello.com: hello.asm asm.com hex2bin.com
	emu2 asm.com hello.  z
	emu2 hex2bin.com hello

trans.com: trans.asm asm.com hex2bin.com
	emu2 asm.com trans.  z
	emu2 hex2bin.com trans

asm.com: asm.asm
	emu2 bin/asm.com asm.  z
	emu2 bin/hex2bin.com asm

hex2bin.com: hex2bin.asm
	emu2 bin/asm.com hex2bin.  z
	emu2 bin/hex2bin.com hex2bin

empty.img:
	dd if=/dev/zero of=a.img bs=327680 count=1

clean:
	rm -f *.com
	rm -f *.exe
	rm -f *.sys
	rm -f *.obj
	rm -f *.crf *.err *.lst *.map *.hex *.prn *.HEX *.PRN
	rm -f *.log
	rm -f pcdos_*.img empty.img
	rm -f msdos_*.img

pcdos: all
	./pcdos

msdos: all
	./msdos
