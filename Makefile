all: ibmcmd.com ibmdos.com ibmbio.com \
     xmscmd.com \
     asm.com hex2bin.com trans.com hello.com \
     mem.com ver.com cls.com \
     ibmsys.com mssys.com \
     pcdos_full.img pcdos_base.img pcdos_dist.img pcdos_diag.img \
     msdos_full.img msdos_base.img msdos_dist.img msdos_diag.img \
     turbo.img

ibmbio.com: ibmbio.exe
	echo 60|emu2 bin/exe2bin.exe ibmbio.exe ibmbio.com

ibmbio.exe: ibmbio.obj
	emu2 bin/link.exe ibmbio,ibmbio,ibmbio,ibmbio,

ibmbio.obj: ibmbio.asm 
	emu2 bin/msmasm.exe ibmbio,ibmbio,ibmbio,ibmbio || rm -f ibmbio.obj

ibmdos.com: ibmdos.exe
	emu2 bin/exe2bin.exe ibmdos.exe ibmdos.com

ibmdos.exe: ibmdos.obj
	emu2 bin/link.exe ibmdos,ibmdos,ibmdos,ibmdos,

ibmdos.obj: ibmdos.asm dos.asm
	emu2 bin/msmasm.exe ibmdos,ibmdos,ibmdos,ibmdos || rm -f ibmdos.obj

msdos_base.img: xmscmd.com ibmbio.com ibmdos.com disks/msdos.img
	cp disks/msdos.img $@
	mattrib -i $@ -h -s ::MSDOS.SYS
	mattrib -i $@ -h -s ::IO.SYS
	mcopy  -o -p -i $@ ibmbio.com ::IO.SYS
	mcopy  -o -p -i $@ ibmdos.com ::MSDOS.SYS
	mcopy  -o -i $@ xmscmd.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::MSDOS.SYS
	mattrib -i $@ +h +s ::IO.SYS
	mdir -w -i $@ ::

pcdos_base.img: ibmcmd.com ibmbio.com ibmdos.com disks/pcdos.img
	cp disks/pcdos.img $@
	mattrib -i $@ -h -s ::IBMDOS.COM
	mattrib -i $@ -h -s ::IBMBIO.COM
	mcopy  -o -p -i $@ ibmbio.com ::IBMBIO.COM
	mcopy  -o -p -i $@ ibmdos.com ::IBMDOS.COM
	mcopy  -o -i $@ ibmcmd.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::IBMDOS.COM
	mattrib -i $@ +h +s ::IBMBIO.COM
	mdir -w -i $@ ::

msdos_dist.img: msdos_base.img mssys.com asm.com hex2bin.com trans.com
	cp msdos_base.img $@
	mcopy  -i $@ bin/msmasm.exe ::MASM.EXE
	mcopy  -i $@ bin/mslink.exe ::LINK.EXE
	mcopy  -i $@ bin/mslib.exe ::LIB.EXE
	mcopy  -i $@ bin/gwbasic.exe ::GWBASIC.EXE
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ mssys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/msformat.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/filcom.com ::FILCOM.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mcopy  -i $@ asm.com ::ASM.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ trans.com ::TRANS.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

msdos_diag.img: msdos_base.img asm.com trans.com \
    hex2bin.com mem.com
	cp msdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ bin/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

msdos_full.img: msdos_base.img asm.com trans.com \
    hex2bin.com mem.com mssys.com hello.asm mshello.bas mkhello.bat
	cp msdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/msmasm.exe ::MASM.EXE
	mcopy  -i $@ bin/mslink.exe ::LINK.EXE
	mcopy  -i $@ bin/mscref.exe ::CREF.EXE
	mcopy  -i $@ bin/mslib.exe ::LIB.EXE
	#mcopy  -i $@ bin/msbasic.com ::MSBASIC.COM
	mcopy  -i $@ bin/gwbasic.exe ::GWBASIC.EXE
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ mssys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/msformat.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/filcom.com ::FILCOM.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mcopy  -i $@ trans.com ::TRANS.COM
	mcopy  -i $@ asm.com ::ASM.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ hello.asm ::HELLO.ASM
	mcopy  -i $@ mkhello.bat ::MKHELLO.BAT
	mcopy  -i $@ mshello.bas ::HELLO.BAS
	mcopy  -i $@ ballc.bas ::BALLC.BAS
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ bin/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::


pcdos_dist.img: msdos_base.img ibmsys.com  
	cp msdos_base.img $@
	mcopy  -i $@ bin/link.exe ::LINK.EXE
	mcopy  -i $@ bin/basic.com ::BASIC.COM
	mcopy  -i $@ bin/basica.com ::BASICA.COM
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ ibmsys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/format.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/comp.com ::COMP.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mcopy  -i $@ samples/art.bas ::ART.BAS
	mcopy  -i $@ samples/ball.bas ::BALL.BAS
	mcopy  -i $@ samples/calendar.bas ::CALENDAR.BAS
	mcopy  -i $@ samples/circle.bas ::CIRCLE.BAS
	mcopy  -i $@ samples/colorbar.bas ::COLORBAR.BAS
	mcopy  -i $@ samples/comm.bas ::COMM.BAS
	mcopy  -i $@ samples/donkey.bas ::DONKEY.BAS
	mcopy  -i $@ samples/mortgage.bas ::MORTGAGE.BAS
	mcopy  -i $@ samples/music.bas ::MUSIC.BAS
	mcopy  -i $@ samples/piechart.bas ::PIECHART.BAS
	mcopy  -i $@ samples/samples.bas ::SAMPLES.BAS
	mcopy  -i $@ samples/space.bas ::SPACE.BAS
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

pcdos_diag.img: pcdos_base.img asm.com trans.com \
    hex2bin.com mem.com
	cp pcdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ bin/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

pcdos_full.img: pcdos_base.img asm.com trans.com \
    hex2bin.com mem.com ibmsys.com hello.asm hello.bas mkhello.bat graph.bas ballc.bas
	cp pcdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/masm.exe ::MASM.EXE
	mcopy  -i $@ bin/link.exe ::LINK.EXE
	mcopy  -i $@ bin/cref.exe ::CREF.EXE
	mcopy  -i $@ bin/lib.exe ::LIB.EXE
	mcopy  -i $@ bin/basic.com ::BASIC.COM
	mcopy  -i $@ bin/basica.com ::BASICA.COM
	mcopy  -i $@ bin/msbasic.com ::MSBASIC.COM
	mcopy  -i $@ bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ bin/chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ ibmsys.com ::SYS.COM
	mcopy  -i $@ bin/edlin.com ::EDLIN.COM
	mcopy  -i $@ bin/format.com ::FORMAT.COM
	mcopy  -i $@ bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ bin/comp.com ::COMP.COM
	mcopy  -i $@ bin/debug.com ::DEBUG.COM
	mcopy  -i $@ bin/mode.com ::MODE.COM
	mcopy  -i $@ asm.com ::ASM.COM
	mcopy  -i $@ trans.com ::TRANS.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ hello.asm ::HELLO.ASM
	mcopy  -i $@ mkhello.bat ::MKHELLO.BAT
	mcopy  -i $@ hello.bas ::HELLO.BAS
	mcopy  -i $@ graph.bas ::GRAPH.BAS
	mcopy  -i $@ ballc.bas ::BALLC.BAS
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ bin/pceinit.com ::PCEINIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

turbo.img: pcdos_base.img
	cp pcdos_base.img $@
	mcopy  -i $@ turbo/turbo.com ::TURBO.COM
	mcopy  -i $@ turbo/turbo-87.com ::TURBO-87.COM
	mcopy  -i $@ turbo/turbo.msg ::TURBO.MSG
	mcopy  -i $@ turbo/tinst.com ::TINST.COM
	mcopy  -i $@ turbo/tinst.msg ::TINST.MSG
	mcopy  -i $@ turbo/tlist.com ::TLIST.COM
	mcopy  -i $@ turbo/read.me ::READ.ME
	mcopy  -i $@ turbo/art.pas ::ART.PAS
	mcopy  -i $@ turbo/calc.pas ::CALC.PAS
	mcopy  -i $@ turbo/calc.hlp ::CALC.HLP
	mcopy  -i $@ turbo/calcmain.pas ::CALCMAIN.PAS
	mcopy  -i $@ turbo/calcdemo.mcs ::CALCDEMO.MCS
	mcopy  -i $@ turbo/sheet.mcs ::SHEET.MCS
	mcopy  -i $@ turbo/cls.pas ::CLS.PAS
	mcopy  -i $@ turbo/color.pas ::COLOR.PAS
	mcopy  -i $@ turbo/sound.pas ::SOUND.PAS
	mcopy  -i $@ turbo/window.pas ::WINDOW.PAS
	mcopy  -i $@ turbo/hilb.pas ::HILB.PAS
	mcopy  -i $@ turbo/test.pas ::TEST.PAS
	mcopy  -i $@ turbo/dosfcall.doc ::DOSFCALL.DOC
	mcopy  -i $@ turbo/external.doc ::EXTERNAL.DOC
	mcopy  -i $@ turbo/intrptcl.doc ::INTRPTCL.DOC
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

xmscmd.com: xmscmd.exe 
	emu2 bin/exe2bin.exe xmscmd.exe xmscmd.com

xmscmd.exe: xmscmd.obj
	emu2 bin/link.exe xmscmd,xmscmd,xmscmd,xmscmd,

xmscmd.obj: mscmd.asm command.asm
	emu2 bin/msmasm.exe mscmd,xmscmd,xmscmd,xmscmd  || rm -f xmscmd.obj

ibmcmd.com: ibmcmd.exe 
	emu2 bin/exe2bin.exe ibmcmd.exe ibmcmd.com

ibmcmd.exe: ibmcmd.obj
	emu2 bin/link.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd,

ibmcmd.obj: ibmcmd.asm command.asm
	emu2 bin/msmasm.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd  || rm -f ibmcmd.obj

ver.com: ver.exe
	emu2 bin/exe2bin.exe ver.exe ver.com

ver.exe: ver.obj
	emu2 bin/link.exe ver,ver,ver,ver, 

ver.obj: ver.asm
	emu2 bin/msmasm.exe ver,ver,ver,ver || rm -f ver.obj

mem.com: mem.exe
	emu2 bin/exe2bin.exe mem.exe mem.com

mem.exe: mem.obj
	emu2 bin/link.exe mem,mem,mem,mem, 

mem.obj: mem.asm
	emu2 bin/msmasm.exe mem,mem,mem,mem || rm -f mem.obj

mssys.com: mssys.exe
	emu2 bin/exe2bin.exe mssys.exe mssys.com

mssys.exe: mssys.obj
	emu2 bin/link.exe mssys,mssys,mssys,mssys, 

mssys.obj: mssys.asm sys.asm
	emu2 bin/msmasm.exe mssys,mssys,mssys,mssys || rm -f mssys.obj

ibmsys.com: ibmsys.exe
	emu2 bin/exe2bin.exe ibmsys.exe ibmsys.com

ibmsys.exe: ibmsys.obj
	emu2 bin/link.exe ibmsys,ibmsys,ibmsys,ibmsys, 

ibmsys.obj: ibmsys.asm sys.asm
	emu2 bin/msmasm.exe ibmsys,ibmsys,ibmsys,ibmsys || rm -f ibmsys.obj

cls.com: cls.exe
	emu2 bin/exe2bin.exe cls.exe cls.com

cls.exe: cls.obj
	emu2 bin/link.exe cls,cls,cls,cls, 

cls.obj: cls.asm
	emu2 bin/msmasm.exe cls,cls,cls,cls || rm -f cls.obj

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
	rm -f turbo.img

pcdos: all
	./pcdos

msdos: all
	./msdos
