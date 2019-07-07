	# 
	# simple asm file to include the P2 JIT compiler
	#
	.section .interp, "a"
	.globl _emustart
	.globl _emuend
_emustart:	
	.incbin "p2lut.bin"
_emuend:	
	

	.text
	.globl _sbrk
	.globl _end
_sbrk:
	la	a1, _heap_ptr
	lw	a2, 0(a1)
	bne	x0,a2,skipset
	la	a2, _end
skipset:
	add	a2, a0, a2
	sw	a2, 0(a1)
	ret

	.data
_heap_ptr:	
	.long	0
