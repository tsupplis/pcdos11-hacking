all: pcdosenh.com pcdosorg.com pcdos.img \
     msdosenh.com msdosorg.com msdos.img

msdos.img: msdosenh.com msorg/msdos.img
	cp msorg/msdos.img msdos.img
	mcopy  -o -i msdos.img msdosenh.com ::COMMAND.COM
	mdir -w -i msdos.img

msdosorg.com: msdosorg.exe
	emu2 exe2bin.exe msdosorg.exe msdosorg.com

msdosorg.exe: msdosorg.obj
	emu2 link.exe msdosorg,msdosorg,msdosorg,msdosorg,

msdosorg.obj: msdosorg.asm
	emu2 masm.exe msdosorg,msdosorg,msdosorg,msdosorg,

msdosenh.com: msdosenh.exe
	emu2 exe2bin.exe msdosenh.exe msdosenh.com

msdosenh.exe: msdosenh.obj
	emu2 link.exe msdosenh,msdosenh,msdosenh,msdosenh,

msdosenh.obj: msdosenh.asm
	emu2 masm.exe msdosenh,msdosenh,msdosenh,msdosenh,

msdosenh.asm: pcdosenh.asm
	cat pcdosenh.asm|sed -e 's/IBMVER \([ ]*\)EQU \([ ]*\)TRUE/IBMVER\1 EQU\2 FALSE/g' \
		|sed -e 's/MSVER \([ ]*\)EQU \([ ]*\)FALSE/MSVER\1 EQU\2 TRUE/g' > msdosenh.asm
	    
msdosorg.asm: pcdosorg.asm
	cat pcdosorg.asm|sed -e 's/IBMVER \([ ]*\)EQU \([ ]*\)TRUE/IBMVER\1 EQU\2 FALSE/g' \
		|sed -e 's/MSVER \([ ]*\)EQU \([ ]*\)FALSE/MSVER\1 EQU\2 TRUE/g' > msdosorg.asm
	    
pcdos.img: pcdosenh.com pcorg/pcdos.img
	cp pcorg/pcdos.img pcdos.img
	mcopy  -o -i pcdos.img pcdosenh.com ::COMMAND.COM
	mdir -w -i pcdos.img

pcdosorg.com: pcdosorg.exe
	emu2 exe2bin.exe pcdosorg.exe pcdosorg.com

pcdosorg.exe: pcdosorg.obj
	emu2 link.exe pcdosorg,pcdosorg,pcdosorg,pcdosorg,

pcdosorg.obj: pcdosorg.asm
	emu2 masm.exe pcdosorg,pcdosorg,pcdosorg,pcdosorg, 

pcdosenh.com: pcdosenh.exe
	emu2 exe2bin.exe pcdosenh.exe pcdosenh.com

pcdosenh.exe: pcdosenh.obj
	emu2 link.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,

pcdosenh.obj: pcdosenh.asm
	emu2 masm.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,

clean:
	rm -f msdosorg.asm msdosenh.asm
	rm -f pcdosorg.exe pcdosorg.obj pcdosorg.com
	rm -f pcdosenh.exe pcdosenh.obj pcdosenh.com
	rm -f msdosorg.exe msdosorg.obj msdosorg.com
	rm -f msdosenh.exe msdosenh.obj msdosenh.com
	rm -f *.crf *.err *.lst *.map
	rm -f pcdos.img msdos.img
