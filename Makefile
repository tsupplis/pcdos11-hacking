all: ibmcmdex.com ibmcmd.com pcdos.img \
     mscmdex.com mscmd.com msdos.img \
     ibmdos.com 

ibmdos.com: ibmdos.exe
	emu2 exe2bin.exe ibmdos.exe ibmdos.com

ibmdos.exe: ibmdos.obj
	emu2 link.exe ibmdos,ibmdos,ibmdos,ibmdos,

ibmdos.obj: ibmdos.asm msdos.asm
	emu2 masm.exe ibmdos,ibmdos,ibmdos,ibmdos || rm -f ibmdos.obj

msdos.img: mscmdex.com msorg/msdos.img
	cp msorg/msdos.img msdos.img
	mcopy  -o -i msdos.img mscmdex.com ::COMMAND.COM
	mdir -w -i msdos.img ::

mscmd.com: mscmd.exe
	emu2 exe2bin.exe mscmd.exe mscmd.com

mscmd.exe: mscmd.obj
	emu2 link.exe mscmd,mscmd,mscmd,mscmd,

mscmd.obj: mscmd.asm
	emu2 masm.exe mscmd,mscmd,mscmd,mscmd || rm -f madosorg.obj

mscmdex.com: mscmdex.exe
	emu2 exe2bin.exe mscmdex.exe mscmdex.com

mscmdex.exe: mscmdex.obj
	emu2 link.exe mscmdex,mscmdex,mscmdex,mscmdex,

mscmdex.obj: mscmdex.asm
	emu2 masm.exe mscmdex,mscmdex,mscmdex,mscmdex || rm -f mscmdex.obj

mscmdex.asm: ibmcmdex.asm
	cat ibmcmdex.asm|sed -e 's/IBMVER \([ ]*\)EQU \([ ]*\)TRUE/IBMVER\1 EQU\2 FALSE/g' \
		|sed -e 's/MSVER \([ ]*\)EQU \([ ]*\)FALSE/MSVER\1 EQU\2 TRUE/g' > mscmdex.asm
	    
mscmd.asm: ibmcmd.asm
	cat ibmcmd.asm|sed -e 's/IBMVER \([ ]*\)EQU \([ ]*\)TRUE/IBMVER\1 EQU\2 FALSE/g' \
		|sed -e 's/MSVER \([ ]*\)EQU \([ ]*\)FALSE/MSVER\1 EQU\2 TRUE/g' > mscmd.asm
	    
pcdos.img: ibmcmdex.com pcorg/pcdos.img
	cp pcorg/pcdos.img pcdos.img
	mcopy  -o -i pcdos.img ibmcmdex.com ::COMMAND.COM
	mdir -w -i pcdos.img ::

ibmcmd.com: ibmcmd.exe
	emu2 exe2bin.exe ibmcmd.exe ibmcmd.com

ibmcmd.exe: ibmcmd.obj
	emu2 link.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd,

ibmcmd.obj: ibmcmd.asm
	emu2 masm.exe ibmcmd,ibmcmd,ibmcmd,ibmcmd  || rm -f ibmcmdex.obj

ibmcmdex.com: ibmcmdex.exe
	emu2 exe2bin.exe ibmcmdex.exe ibmcmdex.com

ibmcmdex.exe: ibmcmdex.obj
	emu2 link.exe ibmcmdex,ibmcmdex,ibmcmdex,ibmcmdex, 

ibmcmdex.obj: ibmcmdex.asm
	emu2 masm.exe ibmcmdex,ibmcmdex,ibmcmdex,ibmcmdex || rm -f ibmcmdex.obj

trans.com: trans.asm
	emu2 qasm.com trans
	emu2 qhex2bin.com trans

io.com: io.asm
	emu2 qasm.com io
	emu2 qhex2bin.com io

asm.com: asm.asm
	emu2 qasm.com asm
	emu2 qhex2bin.com asm

hex2bin.com: hex2bin.asm
	emu2 qasm.com hex2bin
	emu2 qhex2bin.com hex2bin

clean:
	rm -f ibmdos.exe ibmdos.obj ibmdos.com
	rm -f mscmd.asm mscmdex.asm
	rm -f ibmcmd.exe ibmcmd.obj ibmcmd.com
	rm -f ibmcmdex.exe ibmcmdex.obj ibmcmdex.com
	rm -f mscmd.exe mscmd.obj mscmd.com
	rm -f mscmdex.exe mscmdex.obj mscmdex.com
	rm -f asm.com hex2bin.com trans.com io.com
	rm -f *.crf *.err *.lst *.map *.hex *.prn *.HEX *.PRN
	rm -f pcdos.img msdos.img
