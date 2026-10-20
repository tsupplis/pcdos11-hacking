; Microsoft FORMAT boot-sector configuration; build: make msboot.bin.
FALSE   EQU     0
TRUE    EQU     NOT FALSE

MSVER   EQU     TRUE
IBMVER  EQU     FALSE

        include bootsect.asm
