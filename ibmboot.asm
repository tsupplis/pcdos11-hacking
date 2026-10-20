; IBM FORMAT boot-sector configuration; build: make ibmboot.bin.
FALSE   EQU     0
TRUE    EQU     NOT FALSE

MSVER   EQU     FALSE
IBMVER  EQU     TRUE

        include bootsect.asm
