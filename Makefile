all: dos.img

dos.img: command.com source.img
	cp source.img dos.img
	mcopy  -o -i dos.img command.com ::COMMAND.COM
	mdir -w -i dos.img

command.com: command.obj
	dos link.exe command,command,nul,nul,
	dos exe2bin.exe command.exe command.com
	rm -f command.exe

command.obj: command.asm
	dos masm.exe command,command,nul,nul,

clean:
	rm -f command.exe command.obj command.com
	rm -f dos.img 
