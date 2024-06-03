	# 
	# simple asm file to include the P2 JIT compiler
	#
	.section .jitkernel, "a"
	.globl _interpstart
_interpstart:	
	.incbin "p2flash.bin"

	.globl	_riscv_start
_riscv_start:
	la	x1, _start
	jr	x1
	.balign 4

	.text
	.globl _sbrk
	.globl _end
_sbrk:
	la	t1, _heap_ptr
	lw	t2, 0(t1)
	bne	x0,t2,skipset
	la	t2, _end
skipset:
	addi	a0, a0, 15
	andi	a0, a0, 0xfffffff0
	add	t3, a0, t2
	sw	t3, 0(t1)
	mv	a0, t2
	ret

	.globl	__clzsi2
__clzsi2:
	# ENCOD a1, a0
	.insn	r CUSTOM_1, 2, 0x3c, a1, a1, a0
	li	a0, 31
	sub	a0, a0, a1
	ret
	
	.globl	__riscv_save_12
	.globl	__riscv_save_11
	.globl	__riscv_save_10
	.globl	__riscv_save_9
	.globl	__riscv_save_8
	.globl	__riscv_save_7
	.globl	__riscv_save_6
	.globl	__riscv_save_5
	.globl	__riscv_save_4
	.globl	__riscv_save_3
	.globl	__riscv_save_2
	.globl	__riscv_save_1
	.globl	__riscv_save_0
__riscv_save_12:
	addi	sp,sp,-64
	li	t1,0
	sw	s11,12(sp)
	j	save_10_continue
	
	.globl	__riscv_save_10
__riscv_save_11:
__riscv_save_10:
__riscv_save_9:
__riscv_save_8:
	addi	sp,sp,-64
	li	t1,-16
save_10_continue:
	sw	s7,28(sp)
	sw	s8,24(sp)
	sw	s9,20(sp)
	sw	s10,16(sp)
	j	__riscv_save_continue
	
__riscv_save_7:
__riscv_save_6:
__riscv_save_5:
__riscv_save_4:
	addi	sp,sp,-64
	li	t1,-32
__riscv_save_continue:
	sw	ra,60(sp)
	sw	s0,56(sp)
	sw	s1,52(sp)
	sw	s2,48(sp)
	sw	s3,44(sp)
	sw	s4,40(sp)
	sw	s5,36(sp)
	sw	s6,32(sp)
	sub	sp,sp,t1
	jr	t0
	
__riscv_save_3:
__riscv_save_2:
__riscv_save_1:
__riscv_save_0:
	addi	sp,sp,-16
	sw	ra,12(sp)
	sw	s0,8(sp)
	sw	s1,4(sp)
	sw	s2,0(sp)
	jr	t0
	
	.globl	__riscv_restore_12
	.globl	__riscv_restore_11
	.globl	__riscv_restore_10
	.globl	__riscv_restore_9
	.globl	__riscv_restore_8
	.globl	__riscv_restore_7
	.globl	__riscv_restore_6
	.globl	__riscv_restore_5
	.globl	__riscv_restore_4
	.globl	__riscv_restore_3
	.globl	__riscv_restore_2
	.globl	__riscv_restore_1
	.globl	__riscv_restore_0

__riscv_restore_12:
	lw	s11,12(sp)
	addi	sp,sp,16

__riscv_restore_11:
__riscv_restore_10:
__riscv_restore_9:
__riscv_restore_8:
	lw	s7,12(sp)
	lw	s8,8(sp)
	lw	s9,4(sp)
	lw	s10,0(sp)
	addi	sp,sp,16

__riscv_restore_7:
__riscv_restore_6:
__riscv_restore_5:
__riscv_restore_4:
	lw	s3,12(sp)
	lw	s4,8(sp)
	lw	s5,4(sp)
	lw	s6,0(sp)
	addi	sp,sp,16

__riscv_restore_3:
__riscv_restore_2:
__riscv_restore_1:
__riscv_restore_0:
	lw	ra,12(sp)
	lw	s0,8(sp)
	lw	s1,4(sp)
	lw	s2,0(sp)
	addi	sp,sp,16
	ret

	.globl	_clkset
_clkset:
	li	x17, 3001
	ecall
	ret

	.globl	memset
memset:
	li	x17, 3002
	ecall
	ret

	.data
_heap_ptr:	
	.long	0
