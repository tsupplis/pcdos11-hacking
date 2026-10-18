ASM=nasm

all: pceinit.com pceexit.com \

%.sys: %.asm
	$(ASM) -fbin -o $@ $<

pceinit.com: pceinit.asm
	$(ASM) -fbin -o $@ $<

%.com: %.asm
	$(ASM) -fbin -o $@ $<

clean:
	rm -f *.com *.sys
