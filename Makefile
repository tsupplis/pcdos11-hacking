all: pcdos.img

pcdos.img: command.com orig/pcdos.img
	cp orig/pcdos.img pcdos.img
	mcopy  -o -i pcdos.img command.com ::COMMAND.COM
	mdir -w -i pcdos.img

command.com: command.obj
	dos link.exe command,command,command,command,
	dos exe2bin.exe command.exe command.com
	rm -f command.exe

command.obj: command.asm
	dos masm.exe command,command,command,command,

clean:
	rm -f command.exe command.obj command.com
	rm -f *.crf *.err *.lst
	rm -f dos.img 
