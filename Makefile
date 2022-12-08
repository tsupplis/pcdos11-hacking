all: ibmcmdex.com ibmcmd.com pcdos.img \
     ibmdos.com asm.com hex2bin.com trans.com hello.com ibmbio.com

ibmbio.com: ibmbio.exe
	cat 60|emu2 bin/exe2bin.exe ibmbio.exe ibmbio.com

ibmbio.exe: ibmbio.obj
	emu2 bin/link.exe ibmbio,ibmbio,ibmbio,ibmbio,

ibmbio.obj: ibmbio.asm 
	emu2 bin/masm.exe ibmbio,ibmbio,ibmbio,ibmbio || rm -f ibmbio.obj

ibmdos.com: ibmdos.exe
	emu2 bin/exe2bin.exe ibmdos.exe ibmdos.com

ibmdos.exe: ibmdos.obj
	emu2 bin/link.exe ibmdos,ibmdos,ibmdos,ibmdos,

ibmdos.obj: ibmdos.asm msdos.asm
	emu2 bin/masm.exe ibmdos,ibmdos,ibmdos,ibmdos || rm -f ibmdos.obj

pcdos.img: ibmcmdex.com ibmbio.com ibmdos.com asm.com hello.com trans.com hex2bin.com \
  images/blank.img hello.asm hello.bas ball.bas mkhello.bat
	cp images/blank.img pcdos.img
	-mattrib -r -s -i pcdos.img ::IBMDOS.COM
	-mattrib -r -s -i pcdos.img ::IBMBIO.COM
	mcopy  -o -i pcdos.img ibmbio.com ::IBMBIO.COM
	mcopy  -o -i pcdos.img ibmdos.com ::IBMDOS.COM
	mcopy  -o -i pcdos.img ibmcmdex.com ::COMMAND.COM
	mcopy  -o -i pcdos.img bin/masm.exe ::MASM.EXE
	mcopy  -o -i pcdos.img bin/link.exe ::LINK.EXE
	mcopy  -o -i pcdos.img bin/lib.exe ::LIB.EXE
	mcopy  -o -i pcdos.img bin/basic.com ::BASIC.COM
	mcopy  -o -i pcdos.img bin/basica.com ::BASICA.COM
	mcopy  -o -i pcdos.img bin/exe2bin.exe ::EXE2BIN.EXE
	mcopy  -o -i pcdos.img bin/chkdsk.com ::CHKDSK.COM
	mcopy  -o -i pcdos.img bin/sys.com ::SYS.COM
	mcopy  -o -i pcdos.img bin/edlin.com ::EDLIN.COM
	mcopy  -o -i pcdos.img bin/format.com ::FORMAT.COM
	mcopy  -o -i pcdos.img bin/diskcopy.com ::DISKCOPY.COM
	mcopy  -o -i pcdos.img bin/diskcomp.com ::DISKCOMP.COM
	mcopy  -o -i pcdos.img bin/comp.com ::COMP.COM
	mcopy  -o -i pcdos.img bin/debug.com ::DEBUG.COM
	mcopy  -o -i pcdos.img bin/mode.com ::MODE.COM
	mcopy  -o -i pcdos.img asm.com ::ASM.COM
	mcopy  -o -i pcdos.img trans.com ::TRANS.COM
	mcopy  -o -i pcdos.img hello.com ::HELLO.COM
	mcopy  -o -i pcdos.img hex2bin.com ::HEX2BIN.COM
	mcopy  -o -i pcdos.img hello.asm ::HELLO.ASM
	mcopy  -o -i pcdos.img mkhello.bat ::MKHELLO.BAT
	mcopy  -o -i pcdos.img hello.bas ::HELLO.BAS
	[ -f private/pceexit.com ] && mcopy  -o -i pcdos.img private/pceexit.com ::EXIT.COM
	mdir -w -i pcdos.img ::

ibmcmd.com: ibmcmd.exe 
	emu2 bin/exe2bin.exe ibmcmd.exe ibmcmd.com

ibmcmd.exe: ibmcmd.obj
	emu2 bin/link.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd,

ibmcmd.obj: ibmcmd.asm
	emu2 bin/masm.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd  || rm -f ibmcmdex.obj

ibmcmdex.com: ibmcmdex.exe
	emu2 bin/exe2bin.exe ibmcmdex.exe ibmcmdex.com

ibmcmdex.exe: ibmcmdex.obj
	emu2 bin/link.exe ibmcmdex,ibmcmdex,ibmcmdex,ibmcmdex, 

ibmcmdex.obj: ibmcmdex.asm
	emu2 bin/masm.exe ibmcmdex,ibmcmdex,ibmcmdex,ibmcmdex || rm -f ibmcmdex.obj

hello.com: hello.asm asm.com hex2bin.com
	emu2 asm.com hello.ccz
	emu2 hex2bin.com hello

trans.com: trans.asm asm.com hex2bin.com
	emu2 asm.com trans.ccz
	emu2 hex2bin.com trans

asm.com: asm.asm
	emu2 bin/asm.com asm.ccz
	emu2 bin/hex2bin.com asm

hex2bin.com: hex2bin.asm
	emu2 bin/asm.com hex2bin.ccz
	emu2 bin/hex2bin.com hex2bin

clean:
	rm -f ibmdos.exe ibmdos.obj ibmdos.com
	rm -f ibmbio.exe ibmbio.obj ibmbio.com
	rm -f ibmcmd.exe ibmcmd.obj ibmcmd.com
	rm -f ibmcmdex.exe ibmcmdex.obj ibmcmdex.com
	rm -f asm.com hex2bin.com trans.com ibmbio.com hello.com
	rm -f *.crf *.err *.lst *.map *.hex *.prn *.HEX *.PRN
	rm -f *.log
	rm -f pcdos.img
