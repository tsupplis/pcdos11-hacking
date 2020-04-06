all: pcdosenh.com pcdosorg.com pcdos.img

pcdos.img: pcdosenh.com orig/pcdos.img
	cp orig/pcdos.img pcdos.img
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
	rm -f pcdosorg.exe pcdosorg.obj pcdosorg.com
	rm -f pcdosenh.exe pcdosenh.obj pcdosenh.com
	rm -f *.crf *.err *.lst *.map
	rm -f dos.img 
