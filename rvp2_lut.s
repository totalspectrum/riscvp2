	# 
	# simple asm file to include the P2 JIT compiler
	#
	.section .interp, "a"
	.globl _emustart
	.globl _emuend
_emustart:	
	.incbin "p2lut.bin"
_emuend:	
	
