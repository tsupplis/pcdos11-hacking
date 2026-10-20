.PHONY: check-parity check-format-boot check-utility-maps inject-format-boot \
	check-exe2bin check-utility-runtime check-debug all clean test dist

DIST_DISKS=pcdos_full.img pcdos_base.img pcdos_dist.img pcdos_diag.img \
     msdos_full.img msdos_base.img msdos_dist.img msdos_diag.img \
     demos.img turbo.img
UTILITIES=diskcopy.com diskcomp.com chkdsk.com mode.com comp.com filcom.com debug.com \
	exe2bin.exe ibmfmt.com msfmt.com ibmedlin.com msedlin.com mssys.com ibmsys.com \
	ver.com mem.com cls.com \
	asm.com hex2bin.com trans.com
UPX_UTILITIES=upx/asm.com upx/trans.com upx/filcom.com upx/msfmt.com \
	upx/msbasic.com upx/basic.com upx/basica.com upx/ibmfmt.com upx/vi.com
DEMOS=samples/graph.bas hello.z80 mkhello.bat ballc.com samples/ball.bas
CORE=ibmbio.com msdos.com ibmdos.com ibmcmd.com mscmd.com
BOOT=ibmboot.bin msboot.bin
	
all: $(UTILITIES) $(DIST_DISKS) $(CORE) $(BOOT)

#-------------------------------------------------------------------------
#  Distribution
#-------------------------------------------------------------------------

dist: disks.zip

disks.zip: $(DIST_DISKS) LICENSE.md 
	zip -j $@ $(DIST_DISKS) LICENSE.md 

#-------------------------------------------------------------------------
#  Images
#-------------------------------------------------------------------------

msdos_base.img: disks/msdos.img $(CORE)
	cp disks/msdos.img $@
	mattrib -i $@ -h -s ::COMMAND.COM ::MSDOS.SYS ::IO.SYS
	mdel -i $@ ::COMMAND.COM ::MSDOS.SYS ::IO.SYS
	mcopy  -i $@ ibmbio.com ::IO.SYS
	mcopy  -i $@ msdos.com ::MSDOS.SYS
	mcopy  -i $@ mscmd.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::MSDOS.SYS
	mattrib -i $@ +h +s ::IO.SYS
	mdir -w -i $@ ::

pcdos_base.img: disks/pcdos.img $(CORE)
	cp disks/pcdos.img $@
	mattrib -i $@ -h -s ::COMMAND.COM ::IBMDOS.COM ::IBMBIO.COM
	mdel -i $@ ::COMMAND.COM ::IBMDOS.COM ::IBMBIO.COM
	mcopy  -i $@ ibmbio.com ::IBMBIO.COM
	mcopy  -i $@ ibmdos.com ::IBMDOS.COM
	mcopy  -i $@ ibmcmd.com ::COMMAND.COM
	mattrib -i $@ -a ::"*.*"
	mattrib -i $@ +h +s ::IBMDOS.COM
	mattrib -i $@ +h +s ::IBMBIO.COM
	mdir -w -i $@ ::

msdos_dist.img: msdos_base.img $(UTILITIES)
	cp msdos_base.img $@
	mcopy  -i $@ bin/msmasm.exe ::MASM.EXE
	mcopy  -i $@ bin/mslink.exe ::LINK.EXE
	mcopy  -i $@ bin/mslib.exe ::LIB.EXE
	mcopy  -i $@ bin/gwbasic.exe ::GWBASIC.EXE
	mcopy  -i $@ exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ mssys.com ::SYS.COM
	mcopy  -i $@ msedlin.com ::EDLIN.COM
	mcopy  -i $@ msfmt.com ::FORMAT.COM
	mcopy  -i $@ diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ filcom.com ::FILCOM.COM
	mcopy  -i $@ debug.com ::DEBUG.COM
	mcopy  -i $@ mode.com ::MODE.COM
	mcopy  -i $@ asm.com ::ASM.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ trans.com ::TRANS.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

msdos_diag.img: msdos_base.img $(UTILITIES)
	cp msdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ msfmt.com ::FORMAT.COM
	mcopy  -i $@ mssys.com ::SYS.COM
	mcopy  -i $@ debug.com ::DEBUG.COM
	mcopy  -i $@ mon.com ::MON.COM
	mcopy  -i $@ msedlin.com ::EDLIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ ver.com ::VER.COM
	mcopy  -i $@ pce/pceinit.com ::PCEINIT.COM
	mcopy  -i $@ pce/pceexit.com ::PCEEXIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

msdos_full.img: msdos_base.img $(UTILITIES) $(UPX_UTILITIES)
	cp msdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/msmasm.exe ::MASM.EXE
	mcopy  -i $@ bin/mslink.exe ::LINK.EXE
	mcopy  -i $@ bin/mscref.exe ::CREF.EXE
	mcopy  -i $@ bin/mslib.exe ::LIB.EXE
	mcopy  -i $@ bin/gwbasic.exe ::GWBASIC.EXE
	mcopy  -i $@ exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ mssys.com ::SYS.COM
	mcopy  -i $@ msedlin.com ::EDLIN.COM
	mcopy  -i $@ upx/msfmt.com ::FORMAT.COM
	mcopy  -i $@ diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ upx/filcom.com ::FILCOM.COM
	mcopy  -i $@ debug.com ::DEBUG.COM
	mcopy  -i $@ mode.com ::MODE.COM
	mcopy  -i $@ upx/trans.com ::TRANS.COM
	mcopy  -i $@ upx/asm.com ::ASM.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ pce/pceinit.com ::PCEINIT.COM
	mcopy  -i $@ pce/pceexit.com ::PCEEXIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::


pcdos_dist.img: pcdos_base.img $(UTILITIES)
	cp pcdos_base.img $@
	mcopy  -i $@ bin/link.exe ::LINK.EXE
	mcopy  -i $@ bin/basic.com ::BASIC.COM
	mcopy  -i $@ upx/basica.com ::BASICA.COM
	mcopy  -i $@ exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ ibmsys.com ::SYS.COM
	mcopy  -i $@ ibmedlin.com ::EDLIN.COM
	mcopy  -i $@ msfmt.com ::FORMAT.COM
	mcopy  -i $@ diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ comp.com ::COMP.COM
	mcopy  -i $@ debug.com ::DEBUG.COM
	mcopy  -i $@ reference/mode.com ::MODE.COM
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

pcdos_diag.img: pcdos_base.img \
    ibmedlin.com mon.com mem.com ver.com debug.com chkdsk.com ibmfmt.com ibmsys.com
	cp pcdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ ibmfmt.com ::FORMAT.COM
	mcopy  -i $@ ibmsys.com ::SYS.COM
	mcopy  -i $@ debug.com ::DEBUG.COM
	mcopy  -i $@ mon.com ::MON.COM
	mcopy  -i $@ ibmedlin.com ::EDLIN.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ ver.com ::VER.COM
	mcopy  -i $@ pce/pceinit.com ::PCEINIT.COM
	mcopy  -i $@ pce/pceexit.com ::PCEEXIT.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

pcdos_full.img: pcdos_base.img $(UTILITIES) $(UPX_UTILITIES) 
	cp pcdos_base.img $@
	mcopy  -i $@ autoexec.bat ::AUTOEXEC.BAT
	mcopy  -i $@ bin/masm.exe ::MASM.EXE
	mcopy  -i $@ bin/link.exe ::LINK.EXE
	mcopy  -i $@ bin/lib.exe ::LIB.EXE
	mcopy  -i $@ bin/cref.exe ::CREF.EXE
	mcopy  -i $@ upx/basic.com ::BASIC.COM
	mcopy  -i $@ upx/basica.com ::BASICA.COM
	mcopy  -i $@ upx/msbasic.com ::MSBASIC.COM
	mcopy  -i $@ exe2bin.exe ::EXE2BIN.EXE
	mcopy  -i $@ chkdsk.com ::CHKDSK.COM
	mcopy  -i $@ ibmsys.com ::SYS.COM
	mcopy  -i $@ ibmedlin.com ::EDLIN.COM
	mcopy  -i $@ upx/ibmfmt.com ::FORMAT.COM
	mcopy  -i $@ diskcopy.com ::DISKCOPY.COM
	mcopy  -i $@ diskcomp.com ::DISKCOMP.COM
	mcopy  -i $@ comp.com ::COMP.COM
	mcopy  -i $@ debug.com ::DEBUG.COM
	mcopy  -i $@ mode.com ::MODE.COM
	mcopy  -i $@ upx/asm.com ::ASM.COM
	mcopy  -i $@ upx/trans.com ::TRANS.COM
	mcopy  -i $@ hex2bin.com ::HEX2BIN.COM
	mcopy  -i $@ pce/pceinit.com ::PCEINIT.COM
	mcopy  -i $@ pce/pceexit.com ::PCEEXIT.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

turbo.img: disks/formatted.img
	cp disks/formatted.img $@
	mcopy  -i $@ turbo/turbo.com ::TURBO.COM
	mcopy  -i $@ turbo/error.doc ::ERROR.DOC
	mcopy  -i $@ turbo/turbomsg.ovr ::TURBOMSG.OVR
	mcopy  -i $@ turbo/tinst.com ::TINST.COM
	mcopy  -i $@ turbo/tinstmsg.ovr ::TINSTMSG.OVR
	mcopy  -i $@ turbo/tlist.com ::TLIST.COM
	mcopy  -i $@ turbo/calc.pas ::CALC.PAS
	mcopy  -i $@ turbo/calc.hlp ::CALC.HLP
	mcopy  -i $@ turbo/calcmain.pas ::CALCMAIN.PAS
	mcopy  -i $@ turbo/calcdemo.mcs ::CALCDEMO.MCS
	mattrib -i $@ -a ::"*.*"
	mdir -w -i $@ ::

demos.img: disks/formatted.img $(UTILITIES) $(UPX_UTILITIES) $(DEMOS)
	cp disks/formatted.img $@
	mcopy  -i $@ samples/graph.bas ::GRAPH.BAS
	mcopy  -i $@ mshello.bas ::HELLO.BAS
	mcopy  -i $@ ballc.com ::BALLC.COM
	mcopy  -i $@ mem.com ::MEM.COM
	mcopy  -i $@ ver.com ::VER.COM
	mcopy  -i $@ cls.com ::CLS.COM
	mcopy  -i $@ hello.z80 ::HELLO.z80
	mcopy  -i $@ mkhello.bat ::MKHELLO.BAT
	mcopy  -i $@ upx/msbasic.com ::MSBASIC.COM
	mcopy  -i $@ upx/vi.com ::VI.COM
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

#-------------------------------------------------------------------------
#  UPX
#-------------------------------------------------------------------------

upx/basica.com: bin/basica.com
	mkdir -p upx
	upx --8086 -o $@ $<

upx/basic.com: bin/basic.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/msbasic.com: extras/msbasic.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/vi.com: extras/vi.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/asm.com: asm.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/trans.com: trans.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/filcom.com: bin/filcom.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/msfmt.com: msfmt.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<

upx/ibmfmt.com: ibmfmt.com
	mkdir -p upx
	rm -f $@
	upx --8086 -o $@ $<


#-------------------------------------------------------------------------
#  Code Build
#-------------------------------------------------------------------------

ibmbio.com: ibmbio.exe exe2bin.exe
	echo 60|emu2 exe2bin.exe ibmbio.exe ibmbio.com

ibmbio.exe: ibmbio.obj
	emu2 bin/link.exe ibmbio,ibmbio,ibmbio,ibmbio,

ibmbio.obj: ibmbio.asm 
	emu2 bin/msmasm.exe ibmbio,ibmbio,ibmbio,ibmbio || rm -f ibmbio.obj

ibmdos.com: ibmdos.exe exe2bin.exe
	emu2 exe2bin.exe ibmdos.exe ibmdos.com

ibmdos.exe: ibmdos.obj
	emu2 bin/link.exe ibmdos,ibmdos,ibmdos,ibmdos,

ibmdos.obj: ibmdos.asm dos.asm
	emu2 bin/msmasm.exe ibmdos,ibmdos,ibmdos,ibmdos || rm -f ibmdos.obj

msdos.com: msdos.exe exe2bin.exe
	emu2 exe2bin.exe msdos.exe msdos.com

msdos.exe: msdos.obj
	emu2 bin/link.exe msdos,msdos,msdos,msdos,

msdos.obj: msdos.asm dos.asm
	emu2 bin/msmasm.exe msdos,msdos,msdos,msdos || rm -f msdos.obj

mscmd.com: mscmd.exe exe2bin.exe
	emu2 exe2bin.exe mscmd.exe mscmd.com

mscmd.exe: mscmd.obj
	emu2 bin/link.exe mscmd,mscmd,mscmd,mscmd,

mscmd.obj: mscmd.asm command.asm
	emu2 bin/msmasm.exe mscmd,mscmd,mscmd,mscmd  || rm -f mscmd.obj

ibmcmd.com: ibmcmd.exe exe2bin.exe
	emu2 exe2bin.exe ibmcmd.exe ibmcmd.com

ibmcmd.exe: ibmcmd.obj
	emu2 bin/link.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd,

ibmcmd.obj: ibmcmd.asm command.asm
	emu2 bin/msmasm.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd  || rm -f ibmcmd.obj

ver.com: ver.exe exe2bin.exe
	emu2 exe2bin.exe ver.exe ver.com

ver.exe: ver.obj
	emu2 bin/link.exe ver,ver,ver,ver, 

ver.obj: ver.asm
	emu2 bin/msmasm.exe ver,ver,ver,ver || rm -f ver.obj

mem.com: mem.exe exe2bin.exe
	emu2 exe2bin.exe mem.exe mem.com

mem.exe: mem.obj
	emu2 bin/link.exe mem,mem,mem,mem, 

mem.obj: mem.asm
	emu2 bin/msmasm.exe mem,mem,mem,mem || rm -f mem.obj

time10.com: time10.exe exe2bin.exe
	emu2 exe2bin.exe time10.exe time10.com

time10.exe: time10.obj
	emu2 bin/link.exe time10,time10,time10,time10,

time10.obj: time10.asm
	emu2 bin/msmasm.exe time10,time10,time10,time10 || rm -f time10.obj

date10.com: date10.exe exe2bin.exe
	emu2 exe2bin.exe date10.exe date10.com

date10.exe: date10.obj
	emu2 bin/link.exe date10,date10,date10,date10,

date10.obj: date10.asm 
	emu2 bin/msmasm.exe date10,date10,date10,date10 || rm -f date10.obj

mon.com: mon.exe exe2bin.exe
	emu2 exe2bin.exe mon.exe mon.com

mon.exe: mon.obj
	emu2 bin/link.exe mon,mon,mon,mon,

mon.obj: dosmon.asm mon.asm
	emu2 bin/msmasm.exe dosmon,mon,mon,mon || rm -f mon.obj

ibmedlin.com: ibmedlin.exe exe2bin.exe
	emu2 exe2bin.exe ibmedlin.exe ibmedlin.com

ibmedlin.exe: ibmedlin.obj
	emu2 bin/link.exe ibmedlin,ibmedlin,ibmedlin,ibmedlin,

ibmedlin.obj: ibmedlin.asm
	emu2 bin/msmasm.exe ibmedlin,ibmedlin,ibmedlin,ibmedlin || rm -f ibmedlin.obj

msedlin.com: msedlin.exe exe2bin.exe
	emu2 exe2bin.exe msedlin.exe msedlin.com

msedlin.exe: msedlin.obj
	emu2 bin/link.exe msedlin,msedlin,msedlin,msedlin,

msedlin.obj: msedlin.asm
	emu2 bin/msmasm.exe msedlin,msedlin,msedlin,msedlin || rm -f msedlin.obj

mssys.com: mssys.exe exe2bin.exe
	emu2 exe2bin.exe mssys.exe mssys.com

mssys.exe: mssys.obj
	emu2 bin/link.exe mssys,mssys,mssys,mssys, 

mssys.obj: mssys.asm sys.asm
	emu2 bin/msmasm.exe mssys,mssys,mssys,mssys || rm -f mssys.obj

ibmsys.com: ibmsys.exe exe2bin.exe
	emu2 exe2bin.exe ibmsys.exe ibmsys.com

ibmsys.exe: ibmsys.obj
	emu2 bin/link.exe ibmsys,ibmsys,ibmsys,ibmsys, 

ibmsys.obj: ibmsys.asm sys.asm
	emu2 bin/msmasm.exe ibmsys,ibmsys,ibmsys,ibmsys || rm -f ibmsys.obj

cls.com: cls.exe exe2bin.exe
	emu2 exe2bin.exe cls.exe cls.com

cls.exe: cls.obj
	emu2 bin/link.exe cls,cls,cls,cls, 

cls.obj: cls.asm
	emu2 bin/msmasm.exe cls,cls,cls,cls || rm -f cls.obj

ballc.com: ballc.exe exe2bin.exe
	emu2 exe2bin.exe ballc.exe ballc.com

ballc.exe: ballc.obj
	emu2 bin/link.exe ballc,ballc,ballc,ballc, 

ballc.obj: ballc.asm
	emu2 bin/msmasm.exe ballc,ballc,ballc,ballc || rm -f ballc.obj

hello.com: hello.asm asm.com hex2bin.com
	emu2 asm.com hello.  z
	emu2 hex2bin.com hello

hello.asm: hello.z80 trans.com
	emu2 trans.com hello.z80

trans.com: trans.asm asm.com hex2bin.com
	emu2 asm.com trans.  z
	emu2 hex2bin.com trans

asm.com: asm.asm
	emu2 bin/asm.com asm.  z
	emu2 bin/hex2bin.com asm

hex2bin.obj: hex2bin.asm
	emu2 bin/msmasm.exe hex2bin,hex2bin,hex2bin,hex2bin || rm -f hex2bin.obj

hex2bin.com: hex2bin.asm
	emu2 bin/asm.com hex2bin.  z
	emu2 bin/hex2bin.com hex2bin

empty.img:
	dd if=/dev/zero of=a.img bs=327680 count=1

mode.com: mode.exe
	emu2 bin/exe2bin.exe mode.exe mode.com

mode.exe: mode.obj
	emu2 bin/link.exe mode,mode,mode,mode,

mode.obj: mode.asm
	emu2 bin/msmasm.exe mode,mode,mode,mode || rm -f mode.obj

comp.com: comp.exe
	emu2 bin/exe2bin.exe comp.exe comp.com

comp.exe: comp.obj
	emu2 bin/link.exe comp,comp,comp,comp,

comp.obj: comp.asm
	emu2 bin/msmasm.exe comp,comp,comp,comp || rm -f comp.obj

# Emit the complete MZ container through a relocation-free intermediate image.
# Always bootstrap with bin/exe2bin.exe; the reconstructed converter is a result.
exe2bin.exe: exbimage.exe
	emu2 bin/exe2bin.exe exbimage.exe exe2bin.exe

exbimage.exe: exbimage.obj
	emu2 bin/link.exe exbimage,exbimage,exbimage,exbimage,

exbimage.obj: exe2bin.asm
	emu2 bin/msmasm.exe exe2bin,exbimage,exbimage,exbimage || rm -f exbimage.obj

check-utility-runtime: filcom.com filcom.exe exe2bin.exe exbimage.exe
	python3 tools/utility_smoke.py

check-exe2bin: exe2bin.exe
	cmp reference/exe2bin.exe exe2bin.exe
	emu2 exe2bin.exe exbimage.exe exbtest.bin
	cmp exe2bin.exe exbtest.bin
	rm -f exbtest.bin

debug.com: debug.exe
	emu2 bin/exe2bin.exe debug.exe debug.com

debug.exe: debug.obj
	emu2 bin/link.exe debug,debug,debug,debug,

debug.obj: debug.asm
	emu2 bin/msmasm.exe debug,debug,debug,debug || rm -f debug.obj

check-debug: debug.com
	cmp reference/debug.com debug.com
	python3 tools/asm_byte_map.py --check debug
	python3 tools/debug_smoke.py

filcom.com: filcom.exe
	emu2 bin/exe2bin.exe filcom.exe filcom.com

filcom.exe: filcom.obj
	emu2 bin/link.exe filcom,filcom,filcom,filcom,

filcom.obj: filcom.asm
	emu2 bin/msmasm.exe filcom,filcom,filcom,filcom || rm -f filcom.obj

diskcopy.com: diskcopy.exe
	emu2 bin/exe2bin.exe diskcopy.exe diskcopy.com

diskcopy.exe: diskcopy.obj
	emu2 bin/link.exe diskcopy,diskcopy,diskcopy,diskcopy,

diskcopy.obj: diskcopy.asm
	emu2 bin/msmasm.exe diskcopy,diskcopy,diskcopy,diskcopy || rm -f diskcopy.obj

diskcomp.com: diskcomp.exe
	emu2 bin/exe2bin.exe diskcomp.exe diskcomp.com

diskcomp.exe: diskcomp.obj
	emu2 bin/link.exe diskcomp,diskcomp,diskcomp,diskcomp,

diskcomp.obj: diskcomp.asm
	emu2 bin/msmasm.exe diskcomp,diskcomp,diskcomp,diskcomp || rm -f diskcomp.obj

chkdsk.com: chkdsk.exe
	emu2 bin/exe2bin.exe chkdsk.exe chkdsk.com

chkdsk.exe: chkdsk.obj
	emu2 bin/link.exe chkdsk,chkdsk,chkdsk,chkdsk,

chkdsk.obj: chkdsk.asm
	emu2 bin/msmasm.exe chkdsk,chkdsk,chkdsk,chkdsk || rm -f chkdsk.obj

ibmfmt.com: ibmfmt.exe
	emu2 bin/exe2bin.exe ibmfmt.exe ibmfmt.com

ibmfmt.exe: ibmfmt.obj
	emu2 bin/link.exe ibmfmt,ibmfmt,ibmfmt,ibmfmt,

ibmfmt.obj: ibmfmt.asm format.asm fmtboot.inc
	emu2 bin/msmasm.exe ibmfmt,ibmfmt,ibmfmt,ibmfmt || rm -f ibmfmt.obj

msfmt.com: msfmt.exe
	emu2 bin/exe2bin.exe msfmt.exe msfmt.com

msfmt.exe: msfmt.obj
	emu2 bin/link.exe msfmt,msfmt,msfmt,msfmt,

msfmt.obj: msfmt.asm format.asm fmtboot.inc
	emu2 bin/msmasm.exe msfmt,msfmt,msfmt,msfmt || rm -f msfmt.obj

ibmboot.bin: ibmboot.exe
	emu2 bin/exe2bin.exe ibmboot.exe ibmboot.bin

ibmboot.exe: ibmboot.obj
	emu2 bin/link.exe ibmboot,ibmboot,ibmboot,ibmboot,

ibmboot.obj: ibmboot.asm bootsect.asm fmtboot.inc
	emu2 bin/msmasm.exe ibmboot,ibmboot,ibmboot,ibmboot || rm -f ibmboot.obj

msboot.bin: msboot.exe
	emu2 bin/exe2bin.exe msboot.exe msboot.bin

msboot.exe: msboot.obj
	emu2 bin/link.exe msboot,msboot,msboot,msboot,

msboot.obj: msboot.asm bootsect.asm fmtboot.inc
	emu2 bin/msmasm.exe msboot,msboot,msboot,msboot || rm -f msboot.obj

#-------------------------------------------------------------------------
#  Byte-exact PC DOS 1.10 utility reconstructions
#-------------------------------------------------------------------------

check-parity: $(UTILITIES) check-format-boot check-utility-maps check-exe2bin check-utility-runtime check-debug
	cmp reference/chkdsk.com chkdsk.com
	cmp reference/diskcopy.com diskcopy.com
	cmp reference/diskcomp.com diskcomp.com
	cmp reference/edlin.com ibmedlin.com
	cmp reference/msedlin.com msedlin.com
	cmp reference/mode.com mode.com
	cmp reference/comp.com comp.com
	cmp reference/filcom.com filcom.com
	cmp reference/format.com ibmfmt.com
	cmp reference/msformat.com msfmt.com

check-utility-maps: $(UTILITIES) $(BOOT)
	python3 tools/asm_byte_map.py --check diskcopy diskcomp chkdsk mode comp filcom \
		debug exe2bin ibmfmt msfmt ibmboot msboot msedlin ibmdelin

check-format-boot: $(BOOT) tools/format_boot.py
	python3 tools/format_boot.py check reference/format.com ibmboot.bin
	python3 tools/format_boot.py check reference/msformat.com msboot.bin

# Example: make inject-format-boot BOOT_IMAGE=ibmboot.bin
# Writes a separate candidate without altering any reference binary.
inject-format-boot: ibmfmt.com
	@test -n "$(BOOT_IMAGE)" || { echo 'Set BOOT_IMAGE to a compatible 512-byte sector'; exit 1; }
	python3 tools/format_boot.py inject ibmfmt.com "$(BOOT_IMAGE)" --output format-injected.com

clean:
	rm -f $(UTILITIES) $(BOOT) $(CORE)
	rm -f *.com
	rm -f *.exe
	rm -f *.sys
	rm -f *.obj
	rm -f *.crf *.err *.lst *.map *.hex *.prn *.HEX *.PRN
	rm -f *.log
	rm -f pcdos_*.img empty.img
	rm -f msdos_*.img
	rm -f turbo.img demos.img
	rm -rf upx

pcdos: all
	./pcdos

msdos: all
	./msdos
