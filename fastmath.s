	.globl __adddf3
	.globl __addsf3
	.globl __subdf3
	.globl __subsf3
	.globl __muldf3
	.globl __mulsf3
	.globl __divdf3
	.globl __divsf3

__addsf3:
	li	x17, 4000
	ecall
	ret
__subsf3:
	li	x17, 4001
	ecall
	ret
__mulsf3:
	li	x17, 4002
	ecall
	ret
__divsf3:
	li	x17, 4003
	ecall
	ret

__adddf3:
	li	x17, 4004
	ecall
	ret
__subdf3:
	li	x17, 4005
	ecall
	ret
	.globl __muldf3x
__muldf3:
	li	x17, 4006
	ecall
	ret
__divdf3:
	li	x17, 4007
	ecall
	ret

	.globl	sqrtf
	.globl	sqrt
sqrtf:
	li	x17, 4008
	ecall
	ret
sqrt:
	li	x17, 4009
	ecall
	ret
