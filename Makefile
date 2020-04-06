all: pcdosenh.com pcdosorig.com pcdos.img

pcdos.img: pcdosenh.com orig/pcdos.img
	cp orig/pcdos.img pcdos.img
	mcopy  -o -i pcdos.img pcdosenh.com ::COMMAND.COM
	mdir -w -i pcdos.img

pcdosorig.com: pcdosorig.obj
	emu2 link.exe pcdosorig,pcdosorig,pcdosorig,pcdosorig,
	emu2 exe2bin.exe pcdosorig.exe pcdosorig.com
	rm -f pcdosorig.exe

pcdosorig.obj: pcdosorig.asm
	emu2 masm.exe pcdosorig,pcdosorig,pcdosorig,pcdosorig,

pcdosenh.com: pcdosenh.obj
	emu2 link.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,
	emu2 exe2bin.exe pcdosenh.exe pcdosenh.com
	rm -f pcdosenh.exe

pcdosenh.obj: pcdosenh.asm
	emu2 masm.exe pcdosenh,pcdosenh,pcdosenh,pcdosenh,

clean:
	rm -f pcdosorig.exe pcdosorig.obj pcdosorig.com
	rm -f pcdosenh.exe pcdosenh.obj pcdosenh.com
	rm -f *.crf *.err *.lst *.map
	rm -f dos.img 
