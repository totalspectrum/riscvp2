'#define DEBUG_ENGINE
'#define USE_DISASM
'#define DEBUG_THOROUGH
'#define USE_LUT_CACHE

#define ATOMIC_LOCK 15
#define CACHE_LOCK  14

#ifndef USE_LUT_CACHE
'' define one of CACHE_SIZE or TOTAL_SIZE
'' TOTAL_SIZE will define the total size of interpreter + cache
'' CACHE_SIZE will just give that much cache
'' NOTE: if you want to increase cache to more than 64K you will have to
'' modify the alignment; we only have 12 bits for cache offset, and align
'' to a 16 byte (4 bit) boundary
'#define CACHE_SIZE 8192
'#define CACHE_SIZE 32768
#define TOTAL_SIZE 32768
'#define TOTAL_SIZE 65536

'' enable a second set of tags in HUB
#define LVL2_CACHE_TAGS lvl2_tags
#endif

'' enable automatic inlining of functions; still experimental
#define AUTO_INLINE
' enable optimization of cmp with 0
' (not working properly yet)
#define OPTIMIZE_CMP_ZERO
' enable optimization of ptra use
#define OPTIMIZE_PTRA
' use setq+rdlong
#define OPTIMIZE_SETQ_RDLONG

{{
   RISC-V Emulator for Parallax Propeller
   Copyright 2017-2019 Total Spectrum Software Inc.
   Terms of use: MIT License (see the file LICENSE.txt)

   An emulator for the RISC-V processor architecture, designed to run
   in a single Propeller COG.

   This version is stand alone, i.e. does not communicate with a debug
   COG.

   Reads and writes go directly to the host HUB memory. To access COG memory
   or special registers use the CSR instructions. CSRs we know about:
      7Fx - COG registers 1F0-1FF
      BC0 - UART register
      BC1 - wait register  (writing here causes us to wait until a particular cycle)
      BC2 - debug register (writing here dumps debug info to serial)
      BC3 - millisecond timer (32 bits caculated from the cycle counter)
      C00 - cycle counter
      C80 - cycle counter high
      
   Theory of operation:
     We pre-compile instructions and run them from a cache.
     Each RISC-V instruction maps to up to 4 P2 instructions.
     They run inline until the end of the cache, where we have to
     have a jump back to the main interpreter code.
     The ptrb register contains the next pc we should execute;
     this is initialized to the next pc after the cache, so if
     we fall through everything is good.
}}

#define ALWAYS

CON
  WC_BITNUM = 20
  WZ_BITNUM = 19
  IMM_BITNUM = 18
  TOP_OF_MEM = $7C000   ' leaves 16K free at top for debug
  HIBIT = $80000000

  RV_SIGNOP_BITNUM = 30		' RISCV bit for changing shr/sar

  ' instruction flags  
  COMMUTATIVE_CHECK_BITNUM = 9
  XOR_CHECK_BITNUM = 10
  ADD_CHECK_BITNUM = 11
  SHR_CHECK_BITNUM = 12
  ' same thing as dest values
  DST_COMMUTE = 1
  DST_XOR = 2
  DST_ADD = 4
  DST_SHL = 8
  
DAT
		org 0
		'' initial COG boot code
		cogid	   pa
setq_instr	setq	   #0
		coginit	   pa, #@enter
		' config area
		orgh $10
		long	   0		' $10 == reserved
		long	   23_000_000	' $14 == frequency
		long	   0		' $18 == clock mode
		long	   230_400	' $1c == baud

		long	   0[8]		' reserved

		org 0
enter
x0		nop
x1		jmp	#x3
x2		long	TOP_OF_MEM
x3		nop

x4		loc	ptrb, #\@__riscv_start
x5		rdlong	temp, #$18	' get old clock mode
x6		hubset	temp
x7		mov	x1, #$1ff	' will count down

		' initialize LUT memory
x8		neg	x3,#1
x9		nop
x10		wrlut	x3,x1
x11		djnf	x1,#x10

x12		nop
x13		call	#ser_init
x14		call	#jit_init
x15		jmp	#init_vectors

x16		long	0
x17		long	0
x18		long	0
x19		long	0
x20		long	0[12]
		'' these registers must immediately follow x0-x31
x32
opcode		long	0

uart_char	long	0
uart_num	long	0
uart_str	long	0

info2
dis_ptr		long	0
cycleh		long	0
lastcnt		long	0
chfreq		long	$80000000

		'' ISR for CT3 == 0
ct3_isr
		addct3	lastcnt, chfreq
		testb	lastcnt, #31 wc
		addx	cycleh, #0
		reti3
		
		
''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' table of compilation routines for the various opcodes
' the lower 20 bits is generally the address to jump to;
' the exception is that if the upper bit is set then
' it's a pointer to another table indexed by func3
''''''''''''''''''''''''''''''''''''''''''''''''''''''''
optable
{00}		long	HIBIT + loadtab			' TABLE: load instructions
{01}		long	@illegalinstr			' float load
{02}		long	HIBIT + custom0tab		' TABLE: custom0 instructions
{03}		long	@hub_compile_fence		' fence
{04}		long	HIBIT + mathtab			' TABLE: math immediate
{05}		long	@hub_compile_auipc		' auipc instruction
{06}		long	@illegalinstr			' wide math imm
{07}		long	@illegalinstr			' reserved

{08}		long	HIBIT + storetab		' TABLE: store instructions
{09}		long	@illegalinstr			' float store
{0A}		long	HIBIT + custom1tab		' TABLE: custom1
{0B}		long	@hub_compile_atomic		' atomics
{0C}		long	HIBIT + mathtab			' TABLE: math reg<->reg
{0D}		long	@hub_compile_lui		' lui
{0E}		long	@illegalinstr			' wide math reg
{0F}		long	@illegalinstr			' ???

{10}		long	@illegalinstr
{11}		long	@illegalinstr
{12}		long	@illegalinstr
{13}		long	@illegalinstr
{14}		long	@illegalinstr
{15}		long	@illegalinstr
{16}		long	@illegalinstr	' custom2
{17}		long	@illegalinstr

{18}		long	@hub_condbranch	' conditional branch
{19}		long	@hub_jalr
{1A}		long	@illegalinstr
{1B}		long	@hub_jal
{1C}		long	HIBIT + systab	' system
{1D}		long	@illegalinstr
{1E}		long	@illegalinstr	' custom3
{1F}		long	@illegalinstr


sardata		sar	0-0,0-0 wz
subdata		sub	0-0,0-0 wz
subrdata	subr	0-0,0-0 wz
negdata		neg	0-0,0-0 wz
notdata		not	0-0,0-0 wz

		'' code for typical reg-reg functions
		'' such as add r0,r1
		'' needs to handle both immediate and reg rs2
		'' it does this by looking at the opcode:
		'' $13 is immediate
		'' $33 is reg-reg

regfunc
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		cmp	rd, #0	wz	' if rd == 0, emit nop
	if_z	jmp	#hub_emit_nop

		testb	opdata, #SHR_CHECK_BITNUM wc 	' check for sar/shr?
	if_nc	jmp	#nosar
		testb	opcode, #RV_SIGNOP_BITNUM wc	' want sar instead of shr?
	if_c	mov	opdata, sardata
		and	immval, #$1f		' only low 5 bits of immediate
nosar
		'' check for immediates
		test	opcode, #$20 wz
	if_nz	jmp	#reg_reg
		bith	opdata, #IMM_BITNUM

		' special case:
		' xori rA, rB, #-1
		' -> not rA, rB
		testb	opdata, #XOR_CHECK_BITNUM wc
	if_c	jmp	#check_xor

		' special case: addi xa, x0, N
		' can be translated as mv x0, N
		' we can tell it's an add because it will have ADD_CHECK_BITNUM_BITNUM set
		testb	opdata, #ADD_CHECK_BITNUM wc
	if_nc	jmp	#continue_imm
		' for addi
		cmps	immval, #0 wcz
	if_z	jmp	#emit_mov_rd_rs1
	if_b	jmp	#handle_subi
		cmp	rs1, #x0 wz
	if_z	mov	dest, rd
	if_z	jmp	#emit_mvi
	
		'
		' emit an immediate instruction with optional large prefix
		' and with dest being the result
		'
continue_imm
#ifdef OPTIMIZE_CMP_ZERO
		testb	opdata, #WZ_BITNUM wc
	if_c	testbn	opdata, #WC_BITNUM wc
	if_c	mov	zcmp_reg, rd
#endif		
		mov	dest, rd
		call	#emit_mov_rd_rs1
		jmp	#emit_big_instr
check_xor
		tjnf	immval, #continue_imm ' if immval != -1, go to continue_imm
		mov	opdata, notdata
		setd	opdata, rd
		sets	opdata, rs1
		jmp	#emit_opdata
		
		'
		' register<-> register operation
		'
reg_reg
		'' the multiply instructions are in the same
		'' opcode as the "regular" math ones;
		'' check for them here
		mov	temp, opcode
		shr	temp, #25
		and	temp, #$3f
		cmp	temp, #1 wz
	if_z	jmp	#hub_muldiv
	
		testb	opdata, #ADD_CHECK_BITNUM wc
	if_nc	jmp	#nosub
		testb	opcode, #RV_SIGNOP_BITNUM  wc	' need sub instead of add?
	if_nc	jmp	#nosub
	    	mov	opdata, subdata
		' check for special case:
		' sub xA, xB, xA -> subr xA, xA, xB
		cmp	rd, rs2 wz
	if_z	mov	rs2, rs1
	if_z	mov	rs1, rd
	if_z	mov	opdata, subrdata
	
		' check for special case:
		' sub xA, x0, xB -> neg xA, xB
		cmp   rs1, #0 wz
	if_z	mov   opdata, negdata
	if_z	mov   rs1, rd
nosub
		'
		' compiling OP rd, rs1, rs2
		'

		' if commutative and rd == rs2, we can compile
		'   OP rd, rs1
		'
		testb	opdata, #9 wc
	if_nc	jmp	#not_commutative
		cmp	rd, rs2 wz
	if_nz	jmp	#not_commutative
		mov	rs2, rs1
		mov	rs1, rd		' same as old rs2
		jmp	#noaltr
not_commutative
		' if rd is not the same as rs1, we have
		' to issue an ALTR 0, #rd
		'
		cmp	rd, rs1 wz
	if_z	jmp	#noaltr
		sets	altr_op, rd
		mov	jit_instrptr, #altr_op
		call	#emit1
noaltr
		'' now do the operation
		sets	opdata, rs2
		setd  	opdata, rs1
#ifdef OPTIMIZE_CMP_ZERO
		' beware of slt instruction pattern, which has a cmp/cmps
		' with Z set, but which should not set zcmp_reg
		' for this, check for WCZ and skip zcmp_reg setting
		' if C is non-zero
		neg	zcmp_reg, #1 wz
		testb	opdata, #WZ_BITNUM wc
    if_c	testbn	opdata, #WC_BITNUM wc
    if_c      	mov	zcmp_reg, rd
#endif		
emit_opdata
		mov	jit_instrptr, #opdata
		jmp	#emit1

altr_op
		altr	x0, #0-0

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' for multiply and divide we just generate
''    mov rs1, <rs1>
''    mov rs2, <rs2>
''    call #routine
''    mov <rd>, dest
multab
	call	#\imp_mul	  ' mul
	call	#\imp_mulh	  ' mulh
	call	#\imp_mulhsu	  ' mulhsu
	call	#\imp_mulhu	  ' mulhu
	call	#\imp_div
	call	#\imp_divu
	call	#\imp_rem
	call	#\imp_remu

domul_pat
	qmul	rs1, rs2
    	getqx	rd

mul_templ
	mov	rs1, 0-0
	mov	rs2, 0-0
	call	#\illegalinstr
	mov	0-0, rd
	
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' variants for sltu and slt
'' these should generate something like:
''     cmp	rs1, rs2 wc
''     wrc	rd
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sltfunc
		jmp	#\hub_slt_func

sltfunc_pat
		wrc	0-0

'' flag for atomic operations
valid_reservation long 0

''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' load/store operations
'' these look like:
''     mov ptra, rs1
''     rdlong rd, ptra[##immval] wc
''     muxc rd, SIGNMASK (optional, only if wc set on prev. instruction)
''
'' there are some special cases if the immediate value is small:
''    if immval == 0, just do rdlong rd, rs1 wc
''    if immval < 64 and we are a long word read, do:
''      mov ptra, rs1
''      rdlong rd, ptra[immval/4] (skipping the augment)
''
'' the opdata field has:
''   instruction set up for rd/write (load/store share most code)
''   dest field has mask to use for sign extension (or 0 if no mask)
''   src field is address of this routine
''

SIGNBYTE	long	$FFFFFF00
SIGNWORD	long	$FFFF0000

storeop
		'' RISC-V has store value in rs2, we want it in rd
		andn	immval, #$1f
		or	immval, rd
		mov	rd, rs2
		jmp	#hub_ldst_common
loadop
		cmp	rd, #0	wz	' if rd == 0, emit nop
	if_z	jmp	#hub_emit_nop
		jmp	#hub_ldst_common
		

mov_to_ptra
		mov	ptra, 0-0
aug_io
		rdlong	0-0, ##%1000_0000_00000000_00000000

signext_instr
		muxc	0-0, 0-0
signmask
		long	0
locptra		loc	ptra, #\0
addptra		add	ptra, 0-0

wrpin_table
		wrpin	0-0, 0-0
		wxpin	0-0, 0-0
		wypin	0-0, 0-0
		jmp	#\illegalinstr

rdpin_table
		wrc	0-0		' NOTE: S is nonzero, only D is used
		rdpin	0-0, 0-0
		rqpin	0-0, 0-0
		akpin	0-0		' NOTE: D is 1, only S is used
		
dirinstr
		dirl	0-0
testbit_instr
		test	0-0, #1 wc
testpin_instr
		testp	0-0 wc

		'' NOTE: the "call" pattern below is used in several
		'' places
imp_illegal
		call	#\illegal_instr_error

		
LUI_MASK	long	$fffff000

' mask for finding jump address bits

Jmask		long	$fff00fff

imp_jalr
		loc	ptrb, #\(0-0)
		add	ptrb, 0-0
imp_jalr_nooff
		mov	ptrb, 0-0
''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' conditional branch
''   beq rs1, rs2, immval
'' the immediate is encoded a bit oddly, with parts where
'' rd would be
'' rather than using a dispatch table, we decode the func3
'' bits directly
'' the bits are abc
'' where "a" selects for equal (0) or lt (1) (for us, Z or C flag)
''       "b" selects for signed (0) or unsigned (1) compare
''       "c" inverts the sense of a
'' the output will look like:
''        cmp[s] rs1, rs2 wcz
'' then we use the JIT engine to emit a conditional branch to "newpc"
''
''''''''''''''''''''''''''''''''''''''''''''''''''''''''
loc_instr	loc	ptrb, #\0

emit_pc_immval_minus_4
		sub	immval, #4
emit_pc_immval
		andn	loc_instr, jit_loc_mask
		and	immval, jit_loc_mask
		or	loc_instr, immval
		mov	jit_instrptr, #loc_instr
		jmp	#emit1

''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' helper routines for compilation
''''''''''''''''''''''''''''''''''''''''''''''''''''''''

mvins 	      	mov     0-0,#0
negins		neg	0-0,#0

big_temp_0
		mov	0-0, ##0-0

AUG_MASK	long	$ff800000

'
' emit a mov of rs1 to rd
'
emit_mov_rd_rs1
		cmp	rd, rs1 wz
	if_z	ret	    	' nothing to do if rd is rs1 already
		sets	mov_pat,rs1
		setd	mov_pat,rd
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	jit_instrptr, #mov_pat
		jmp	#emit1
mov_pat		mov	0-0,0-0

'=========================================================================
' system instructions
'=========================================================================

''
'' the register read/write routines
'' these basically look like:
''    mov rd, <reg>
''    op  <reg>, rs1
''
csrrw
		jmp	#\hub_compile_csrw

coginit_pattern
		mov	temp, 0-0	' rs1
		setq	0-0   		' rs3
		coginit temp,0-0 wc	' rs2
		negc	0-0,temp 	' rd
		
getct_pat
		getct	0-0
getcth_pat
		mov	0-0, cycleh
csrvec_read_instr
		call	#\ser_rx
		mov	0-0, pb
csrvec_write_instr
		mov	pb, 0-0
		call	#\ser_tx
singledest_pat
		cogstop	0-0
	if_c	neg	0-0, #1
	
'=========================================================================
' custom instructions
'=========================================================================
pinsetinstr
		jmp	#\hub_pinsetinstr
'=========================================================================
		'' VARIABLES
rd		long	0
rs1		long	0
rs2		long	0
immval		long	0
opdata
divflags	long	0

#ifdef OPTIMIZE_SETQ_RDLONG
subptra		sub	ptra, 0-0
#endif

#ifdef OPTIMIZE_CMP_ZERO
zcmp_reg	long	-1	' register last compared to 0 as part of instruction
#endif
#ifdef OPTIMIZE_PTRA
ptra_reg	long	-1	' register contained in ptra
#endif
#ifdef AUTO_INLINE
ra_reg		long	1	' register used for return address
ra_val		long	0	' address in ra, if known
#endif
	''
	'' opcode tables
	''
start_of_tables
''''' math indirection table
'' upper bits are acutlly instructions we wish to use
'' dest bits contain flags: 1 -> operation is commutative
''                          2 -> operation is xor
''                          4 -> operation is add
''                          8 -> operation is shift
mathtab
adddata		add	DST_ADD+DST_COMMUTE,regfunc wz
shldata		shl	DST_SHL,regfunc wz
cmpsdata	cmps	0,sltfunc    wcz
cmpdata		cmp	0,sltfunc    wcz
xordata		xor	DST_XOR+DST_COMMUTE,regfunc wz
shrdata		shr	DST_SHL,regfunc wz
ordata		or	DST_COMMUTE,regfunc wz
anddata		and	DST_COMMUTE,regfunc wz
loadtab
		rdbyte	SIGNBYTE, loadop wcz
		rdword	SIGNWORD, loadop wcz
		rdlong	0, loadop wz
		long	@illegalinstr
		rdbyte	0, loadop wz
		rdword	0, loadop wz
ldlongdata	rdlong	0, loadop wz
		long	@illegalinstr
storetab
		wrbyte	0, storeop
		wrword	0, storeop
swlongdata	wrlong	0, storeop
		long	@illegalinstr
		long	@illegalinstr
		long	@illegalinstr
		long	@illegalinstr
		long	@illegalinstr

systab		long	@hub_syspriv
		mov	0,csrrw
		or	0,csrrw
		andn	0,csrrw
		long	@illegalinstr
		mov	0,#csrrw	' csrrwi
		or	0,#csrrw	' csrrsi
		andn	0,#csrrw	' csrrci

custom0tab
		long	@illegalinstr
		long	@illegalinstr
		'' dirl, drvl, etc. only have dest fields, so
		'' we cannot do the usual trick of putting the
		'' address in the source field;
		'' instead, we use the AND instruction and put
		'' the actual instruction bits in the dest field
		''
		and	%001011000, pinsetinstr		' drvl
		and	%001010000, pinsetinstr		' fltl
		and	%001001000, pinsetinstr		' outl
		and	%001000000, pinsetinstr		' dirl
		long	@hub_wrpininstr
		long	@hub_rdpininstr
custom1tab
		long	@hub_coginitinstr
		long	@hub_singledestinstr
		long	@hub_stdinstr
		long	@illegalinstr
		long	@illegalinstr
		long	@illegalinstr
		long	@illegalinstr
		long	@illegalinstr
end_of_tables

'' utility routines for emitting 1-4 words
emit1
		mov	pb, #1
		jmp	#jit_emit
emit2
		mov	pb, #2
		jmp	#jit_emit
emit4
		mov	pb, #4
		jmp	#jit_emit

'' pattern for flushing the instruction cache
flush_icache_pat
		call	#\jit_reinit_cache
		
		''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		'' code for doing compilation
		'' called from the JIT engine loop
		''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		'' utility called at start of line
compile_bytecode_start_line
#ifdef DEBUG_THOROUGH
		call	#debug_print
#endif		
#ifdef AUTO_INLINE
		neg	ra_reg, #1
		neg	ra_val, #1
#endif
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
#ifdef OPTIMIZE_PTRA
	_ret_	neg	ptra_reg, #1
#else	
		ret
#endif		
		'' compile one opcode
compile_bytecode
#ifdef OPTIMIZE_PTRA		
		' if last instruction modified ptra_reg, then invalidate it
		cmp	rd, ptra_reg wz
	if_z	neg	ptra_reg, #1
#endif	
#ifdef AUTO_INLINE	
		cmp	rd, ra_reg wz	' did we just modify the return address?
	if_z	neg	ra_reg, #1
#endif
		' fetch the actual RISC-V opcode
		rdlong	opcode, ptrb++
		test	opcode, #3 wcz
  if_z_or_c	jmp	#hub_compressed_instr		' low bits must both be 3; otherwise a 16 bit instruction
  
    		'' decode instruction
		mov	immval, opcode
		sar	immval, #20
		mov	rs2, immval
		and	rs2, #$1f
		mov	rs1, opcode
		shr	rs1, #15
		and	rs1, #$1f
		mov	func3, opcode
		shr	func3,#12
		and	func3,#7
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f
	
		'' now look up in table
		mov	temp, opcode
		shr	temp, #2
		and	temp, #$1f
		alts	temp, #optable
		mov	opdata, 0-0		' fetch long from table; set C if upper bit set

		testb	opdata, #31 wc
	if_nc	jmp	opdata
		' need to do a table indirection
		and	opdata, #$1ff		' clear upper bits
		alts	func3, opdata		' do table indirection
		mov	opdata, 0-0 wc
	if_nc	jmp	opdata			' if top bit clear, jump to instruction

		mov	temp, opdata
		and	temp, #$1ff
		jmp	temp+0			' compile the instruction, return to JIT loop


#include "jit/jit_engine.spinh"

jit_cacheptr	long	0
jit_cachepc	long	0
jit_orig_cachepc
		long	0
jit_orig_ptrb	long	0

#ifndef DEBUG_ENGINE
		' fit the multiply routine into COG
		' multiply rd = rs1 * rs2, giving only the low word
imp_mul
		getword	temp, rs1, #1	' temp = ahi
		getword	rd, rs2, #1	' rd = bhi
		mul	temp, rs2
		mul	rd, rs1
		add	rd, temp
		shl	rd, #16
		mul	rs1, rs2
	_ret_	add	rd, rs1
#endif

		fit	$1d0

' reserved for float use
  	 	org	$1d0
float_reserved
		res	16
		
		org	$1e0
		' scratch registers needed only for the
		' compiler; these may be overwritten at run time
jit_instrptr	res	1
jit_instr	res	1
jit_temp	res	1
jit_temp2	res	1
jit_condition	res	1
dis_instr	res	1
dis_temp2	res	1
dis_temp1	res	1

dis_cnt		res	1
uart_temp	res	1
temp		res	1
temp2		res	1
dest		res	1
func3		res	1
func2		res	1
ioptr		res	1
		fit	$1f0

''
'' some lesser used routines that can go in HUB memory
''
		orgh	$800
		
		'' RISC-V register info: BC0-BCF
		'' each entry is 2 longs: a vector for CSR reads
		'' and one for writes
		'' the reads return a value in pb
		'' the writes take a value in pb
		'' $0667EE01 is the instruction:
		''    _ret_ neg pb, #1
		'' which is the default
#define DEFAULT_CSR_INSTRUCTION $0667EE01

init_vectors
		'' this is a hook for expanding the interpreter
		jmp	#\setup	      		' first; early initialization
post_setup_hook
		jmp	#\post_setup_vec	' called after setup

csr_vectors
		long   DEFAULT_CSR_INSTRUCTION[32]

		'''''''''''''''''''''''''''''''''''''''''
		'' actual CSR utility routines
		'' these all receive/return in pb
		'''''''''''''''''''''''''''''''''''''''''
uart_read_csr
		call	#\ser_rx
	_ret_	mov	pb, uart_char
uart_write_csr
		mov	uart_char, pb
		jmp	#ser_tx
waitcnt_read_csr
	_ret_	getct	pb

waitcnt_write_csr
		addct1	pb, #0
		waitct1
		ret
debug_read_csr
	_ret_	mov	pb, #0
debug_write_csr
		jmp	#\debug_print
		
millis_read_csr
		' calculate elapsed milliseconds into pb
		mov	dest, cycleh
		getct	temp
		cmp	dest, cycleh wz
	if_nz	jmp	#millis_read_csr
		' now we have a 64 bit number (dest, temp)
		' want to divide this by (frequency/1000) to get milliseconds
		rdlong	pb, #$14    	' get frequency
		qdiv	pb, ##1000
		getqx	pb		' now have freq/1000 in pb
		setq	dest
		qdiv	temp, pb
		getqx	pb
		ret

millis_write_csr
	_ret_	mov	pb, #0
	

		'''''''''''''''''''''''''''''''''''''''''
		'' now start execution
setup
		'' set up interrupt for CT3 == 0
		'' to measure cycle rollover
		getct	lastcnt
		and	lastcnt, chfreq
		addct3	lastcnt, chfreq
		mov   IJMP3, #ct3_isr
		setint3	#3   '' ct3

		''
		'' set up CSR vectors
		'' we should skip individual vectors if they
		'' were modified by the user
		''

		loc	ptra, #\@csr_vectors
		loc	pa, #\@uart_read_csr
		call	#install_vector
		loc	pa, #\@uart_write_csr
		call	#install_vector

		loc	pa, #\@waitcnt_read_csr
		call	#install_vector
		loc	pa, #\@waitcnt_write_csr
		call	#install_vector
		
		loc	pa, #\@debug_read_csr
		call	#install_vector
		loc	pa, #\@debug_write_csr
		call	#install_vector

		loc	pa, #\@millis_read_csr
		call	#install_vector
		loc	pa, #\@millis_write_csr
		call	#install_vector

		'' call the post setup hook
		call	#post_setup_hook

		'' run the JIT loop forever
		jmp	#jit_set_pc

		' write a "jump" instruction to the address in pa
		' into ptra; skip if *ptra is already initialized
install_vector
		rdlong	temp, ptra
		cmp	temp, ##DEFAULT_CSR_INSTRUCTION wz
	if_nz	add	ptra, #4
	if_nz	ret
		or	pa, ##$FD800000	' turn into absolute JMP
		wrlong	pa, ptra++
		ret

post_setup_vec
#ifdef DEBUG_ENGINE
		mov	uart_str, ##@boot_msg
		call	#ser_str
#endif		
		ret
		
#include "jit/util_serial.spin2"

#ifdef DEBUG_ENGINE
#include "jit/util_disasm.spin2"
#endif

'=========================================================================
' MATH ROUTINES
'=========================================================================

#ifdef DEBUG_ENGINE
		' multiply rd = rs1 * rs2, giving only the low word
imp_mul
		getword	temp, rs1, #1	' temp = ahi
		getword	rd, rs2, #1	' rd = bhi
		mul	temp, rs2
		mul	rd, rs1
		add	rd, temp
		shl	rd, #16
		mul	rs1, rs2
	_ret_	add	rd, rs1
#endif

imp_mulhu
		' multiply rs1*rs2, giving full 64 bit result
		' with rs1 =  low word,
		'      rd = high word
		getword temp, rs1, #1	' temp = ahi
		getword	temp2, rs2, #1	' temp22 = bhi
		mov	rd, temp
		mul	rd, temp2
		mul	temp, rs2
		mul	temp2, rs1
		add	temp, temp2 wc
		getword	temp2, temp, #1
		bitc	temp2, #16
		shl	temp, #16
		mul	rs1, rs2
		add	rs1, temp wc
    _ret_	addx	rd, temp2
		
    		' for signed 32 bit multiplication,
		' do (hi,lo) = x*y as unsigned, then correct via
		' if (x < 0) hi -= y
		' if (y < 0) hi -= x
imp_mulh
		qmul	rs1, rs2
		mov	temp, #0
		testb	rs1, #31 wc
	if_c	add	temp, rs2
		testb	rs2, #31 wc
	if_c	add	temp, rs1
		getqy	rd
	_ret_	sub	rd, temp
		
imp_mulhsu
		qmul	rs1, rs2
		mov	temp, #0
		testb	rs1, #31 wc
	if_c	add	temp, rs2
		getqy	rd
	_ret_	sub	rd, temp

#ifdef NEVER
print_rd
		mov	uart_char, #"!"
		call	#ser_tx
		mov	uart_num, rd
		jmp	#ser_hex
#endif

		'' calculate rs1 / rs2
imp_divu
		tjz	rs2, #div_by_zero
		setq	#0
		qdiv	rs1, rs2
	_ret_	getqx	rd


div_by_zero
	_ret_	neg	rd, #1

imp_remu
		tjz	rs2, #rem_by_zero
		setq	#0
		qdiv	rs1, rs2
	_ret_	getqy	rd
		
rem_by_zero
	_ret_	mov	rd, rs1

imp_rem
		mov	divflags, rs1	' remainder should have sign of rs1
		abs	rs1, rs1
		abs	rs2, rs2
		call	#imp_remu
		testb	divflags, #31 wc
	_ret_	negc	rd

		'' calculate signed rs1 / rs2
imp_div
		mov	divflags, rs2 wz
	if_z	jmp	#div_by_zero
		xor	divflags, rs1
		abs	rs1,rs1
		abs	rs2,rs2
		call	#imp_divu
		testb	divflags, #31 wc	' check sign
	_ret_	negc	rd

hub_ldst_common
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1		' assume Z reg trashed
#endif		
		mov	signmask, opdata	' save if we need sign mask
		cmp	immval, #0 wz
	if_nz	jmp	#ldst_need_offset
		mov	dest, rs1
		jmp	#final_ldst
ldst_need_offset
		' if this is an offset ld/st instruction,
		' then copy the base register into ptra
		' mov ptra, rs1
		' wrbyte rd, ptra[immval]
		' can skip the "mov" if ptra already holds
		' rs1
#ifdef OPTIMIZE_PTRA		
		cmp	ptra_reg, rs1 wz
	if_z	jmp	#skip_ptra_mov
		mov	ptra_reg, rs1
#endif	
		sets	mov_to_ptra, rs1
		mov	jit_instrptr, #mov_to_ptra
		call	#emit1		
skip_ptra_mov
#ifdef OPTIMIZE_PTRA
		'' check to see if we're about to trash the register we
		'' think is in ptra
		cmp	 rd, ptra_reg wz
	if_z	neg	 ptra_reg, #1
#endif	
		'' see if this is a short offset
		mov	temp, #15
		' note: low bits of func3 == 0 for byte, 1 for word, 2 for long
		' which is what we want
		and	func3, #3
		mov	temp, immval
		sar	temp, func3
#ifdef NEW_HW
		cmps	temp, #31 wcz
	if_a	jmp	#big_offset
		cmps	temp, ##-32 wcz
	if_b	jmp	#big_offset
		and	temp, #$3f
#else
		cmps	temp, #15 wcz
	if_a	jmp	#big_offset
		cmps	temp, #0 wcz
	if_b	jmp	#big_offset
		and	temp, #$f
#endif
		mov	immval, temp
		'
		' OK, we can emit a simple
		' rdlong rd, ptra[immval]
		'
		or	immval, #%1000_00000	' SUP mode for ptra[immval]
		sets	opdata, immval
		bith	opdata, #IMM_BITNUM	' change to imm mode
		
		jmp	#do_opdata_and_sign
big_offset
		'
		' here we have a big offset
		'
		and	immval, jit_loc_mask	' isolate offset 20 bits
		sets	opdata, immval
		setd	opdata, rd
		bith	opdata, #IMM_BITNUM	' change to imm mode
		mov	aug_io+1, opdata
		
		' set up the augmented prefix
		shr	immval, #9
		andn	aug_io, ##$7ff	' clear out bottom 11 bits of augment
		or	aug_io, immval
		mov	jit_instrptr, #aug_io
		call	#emit2
		jmp	#check_for_signext
		
final_ldst
		'' now the actual rd/wr instruction
		'' opdata contains a template like
		''   rdword SIGNWORD, loadop wc
		''
		'' now change the opdata to look like
		''   rdword rd, ptra
		sets	opdata, dest
do_opdata_and_sign		
		setd	opdata, rd
#ifdef OPTIMIZE_CMP_ZERO
		testb	opdata, #WZ_BITNUM wc	' do we test Z in the load
	if_c	mov	zcmp_reg, rd	   	' if so, set register
#endif		
		mov	jit_instrptr, #opdata
		call	#emit1
check_for_signext
		shr	signmask, #9
		and	signmask, #$1ff wz	' check for sign mask
		'' see if we need a sign extension instruction
	if_z	ret
		setd	signext_instr, rd
		sets	signext_instr, signmask
		mov	jit_instrptr, #signext_instr
		mov	pb, #1
		jmp	#jit_emit

emit_mvi
		cmp	immval, #0 wcz
	if_b	mov	opdata, negins
	if_b	neg	immval
	if_ae	mov	opdata, mvins
emit_big_instr
		mov	big_temp_0+1,opdata
		cmp	dest, #x0 wz
	if_z	ret	' never write to x0
		mov	temp, immval
		shr	temp, #9	wz
		and	big_temp_0, AUG_MASK
		or	big_temp_0, temp
		and	immval, #$1FF
		sets	big_temp_0+1, immval
		setd	big_temp_0+1, dest
		mov	jit_instrptr, #big_temp_0
		'' if the augment bits are nonzero, emit augment
	if_nz	mov	pb, #2
	if_nz	jmp	#jit_emit
		'' otherwise skip the augment part
		add	jit_instrptr, #1
		jmp	#emit1

'
' emit a no-op
' nop is a special case in the P2 instruction set (all 0)
' fortunately, if we end up having to conditionalize the no-op,
' it'll be compiled as "ror 0,0" and location 0 always contains 0,
' so it'll still be a no-op
'
hub_emit_nop
		mov	opdata, #0	' nop instruction
		jmp	#emit_opdata

'
hub_muldiv
	alts	func3, #multab
	mov	opdata, 0-0 wz
 if_z	jmp	#handle_mul

handle_plain_call
#ifdef OPTIMIZE_CMP_ZERO
	neg	zcmp_reg, #1	' subroutine may trash Z
#endif	
	sets	mul_templ, rs1
	sets	mul_templ+1, rs2
	mov	mul_templ+2, opdata
	cmp	rd, #0 wz
if_nz	setd	mul_templ+3, rd
if_z	setd	mul_templ+3, #temp
	mov	jit_instrptr, #mul_templ
	jmp	#emit4
handle_mul
	setd	domul_pat, rs1
	sets	domul_pat, rs2
	setd	domul_pat+1, rd
	mov	jit_instrptr, #domul_pat
	jmp	#emit2

		' convert addi A, B, -N to sub A, B, N
handle_subi
		neg	immval
		mov	opdata, subdata
		bith	opdata, #IMM_BITNUM
		jmp	#continue_imm

hub_jal
		cmp	rd, #0 wz	' check for having to save return address
	if_ne	mov	immval, ptrb	' get return address
	if_ne	mov	dest, rd
	if_ne	call	#emit_mvi	' move into rd
#ifdef AUTO_INLINE
#ifdef OPTIMIZE_PTRA
		neg	ptra_reg, #1	' FIXME??? not sure why this is necessary
#endif		
		mov	ra_reg, rd	' save register and value
		mov	ra_val, ptrb
		mov	rd, #0
#endif	
		mov	immval, opcode
		sar	immval, #20	' sign extend, get some bits in place
		and	immval, Jmask
		test	immval, #1 wc	' check old bit 20
		mov	temp, opcode
		andn	temp, Jmask
		or	immval, temp
		andn	immval, #1  	' clear low bit
		muxc	immval, ##(1<<11)
#ifdef AUTO_INLINE
		add	ptrb, immval
	_ret_	sub	ptrb, #4
#else
		add	immval, ptrb	' calculate branch target
		mov	jit_condition, #$F	    ' unconditional jump
		sub	immval, #4     	' adjust for PC offset
		jmp	#issue_branch_cond
#endif

hub_jalr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
#ifdef AUTO_INLINE
		cmp	rs1, ra_reg wz
	if_z	tjnf	ra_val, #skip_ret
#endif
		' set up offset in ptrb
		and	immval, jit_loc_mask wz
	if_nz	jmp	#.need_offset
		sets	imp_jalr_nooff, rs1
		mov	jit_instrptr, #imp_jalr_nooff
		call	#emit1
		jmp	#.load_retaddr
.need_offset
		andn	imp_jalr, jit_loc_mask
		or	imp_jalr, immval
		sets	imp_jalr+1, rs1
		mov	jit_instrptr, #imp_jalr
		call	#emit2
.load_retaddr
		' now emit the final load
		mov	immval, ptrb	' get return address
		mov	dest, rd wz
	if_nz	call	#emit_mvi	' move into rd

		' and emit the indirect branch code
		mov	jit_condition, #$f
		jmp	#jit_emit_indirect_branch
#ifdef AUTO_INLINE
skip_ret
		mov	ptrb, ra_val
		ret
#endif

hub_condbranch		
		test	func3, #%100 wz
	if_z	mov	jit_condition, #%1010	' IF_Z
	if_nz	mov	jit_condition, #%1100	' IF_C
		test	func3, #%001 wz
	if_nz	xor	jit_condition, #$f	' flip sense
		test	func3, #%010 wz
		'' write the compare instruction
	if_z	mov	opdata,cmpsdata
	if_nz	mov	opdata, cmpdata
		setd	opdata, rs1
		sets	opdata, rs2
		mov	jit_instrptr, #opdata
		'' we can skip the cmp if the Z flag is required and
		'' it's already set
#ifdef OPTIMIZE_CMP_ZERO
		test	func3, #%100 wz
	if_z	cmp	rs2, #0 wz
	if_z	cmp	rs1, zcmp_reg wz
	if_nz	neg	zcmp_reg, #1
	if_nz	call	#emit1
#else
		call	#emit1
#endif
		'' now we need to calculate the new pc
		'' this means re-arranging some bits
		'' in immval
		andn 	immval, #$1f
		or	immval, rd
		test  	immval, #1 wc
		bitc	immval, #11
		andn	immval, #1
		add	immval, ptrb
		'' BEWARE! ptrb has stepped up by 4 or 2, so we need to
		'' adjust accordingly
		sub	immval, #4

		''
		'' issue a conditional branch to the value in
		'' "immval"
		'' jit_condition has the P2 flags to use for the condition
		'' ($F for unconditional branch)
		''
issue_branch_cond

		' and go create the branch
		mov	jit_branch_dest, immval
		jmp	#jit_emit_direct_branch

c_illegalinstr
		mov	immval, ptrb
		add	immval, #2
		jmp	#do_illegal
		
illegalinstr
hub_illegalinstr
		mov	immval, ptrb
do_illegal
		call	#emit_pc_immval_minus_4
		mov	jit_instrptr, #imp_illegal
		call	#emit1
		mov	jit_condition, #0
		jmp	#jit_emit_direct_branch

hub_compile_fence
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		cmp	func3, #0 wz
	if_z	ret			' func3 == 0 means fence; just ignore
		cmp	func3, #1 wz	' check fence.i
	if_nz	jmp	#illegalinstr
		'' fence.i: insert a cache flush command
		mov	jit_instrptr, #flush_icache_pat
		call	#emit1
		mov	jit_condition, #0
		mov	jit_branch_dest, ptrb
		jmp	#jit_emit_direct_branch
		
hub_compile_auipc
		mov	immval, opcode
		and	immval, LUI_MASK
		add	immval, ptrb
		sub	immval, #4
		jmp	#lui_aui_common
hub_compile_lui
		mov	immval, opcode
		and	immval, LUI_MASK
lui_aui_common
		'' at this point we might want to check for a coming
		'' addi rd, rd, X
		'' if there is one, we can fold it in with this operation
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	dest, rd
		rdlong	temp2, ptrb	'' peek ahead at next instruction
		mov	temp, temp2
		and	temp, ##$fff00000	' extract immediate
		or	temp, #$013	'' base addi instruction
		shl	rd, #7
		or	temp, rd
		shl	rd, #8
		or	temp, rd
		cmp	temp, temp2 wz	'' check for desired addi instruction
	if_nz	jmp	#emit_mvi	'' if not equal just emit and continue
		'' OK, merge the coming addi
		add    ptrb, #4
		sar    temp, #20
		add    immval, temp
		jmp    #emit_mvi
		
hub_slt_func
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		cmp	rd, #0	wz	' if rd == 0, emit nop
	if_z	jmp	#\hub_emit_nop

		'' MUL shares the same opcode space, so look for it
		mov	temp, opcode
		shr	temp, #25
		and	temp, #$3f
		cmp	temp, #1 wz
	if_z	jmp	#hub_muldiv
		
		andn	opdata, #$1ff	' zero out source
		setd	sltfunc_pat, rd
		'' check for immediate
		test	opcode, #$20 wz
	if_nz	jmp	#slt_reg
	
		'' set up cmp with immediate here	
		bith	opdata, #IMM_BITNUM
		mov	dest, rs1
		call	#emit_big_instr	' cmp rs1, ##immval
		jmp	#slt_fini
slt_reg
		'' for reg<->reg, output cmp rs1, rs2
		sets	opdata, rs2
		setd	opdata, rs1
		mov	jit_instrptr, #opdata
		call	#emit1
slt_fini
		mov	jit_instrptr, #sltfunc_pat
		jmp	#emit1	' return from there to our caller
		

hub_compile_csrw
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		getnib	func3, immval, #2
		and	immval, #$1FF

		'' check for COG I/O e.g. 7f4
		cmp	func3, #7 wz
	if_nz	jmp	#not_cog

		'' first, emit a mov to get the old register value
		cmp	rd, #0 wz
	if_z	jmp	#skip_rd
		setd	mov_pat, rd
		sets	mov_pat, immval
		mov	jit_instrptr, #mov_pat
		call	#emit1
skip_rd
		'' now emit the real operation
		setd	opdata, immval
		sets	opdata, rs1
		jmp	#emit_opdata
not_cog
		'' check for standard read-only regs
		cmp	func3, #$C wz
	if_nz	jmp	#not_standard

		'' write to 0? that's a no-op
	    	cmp	rd, #0 wz
	if_z	jmp	#hub_emit_nop

		'' $c00 == mcount (cycles counter)
		cmp	immval, #0 wz
	if_nz	jmp	#not_mcount

		mov	opdata, getct_pat
  		setd	opdata, rd
		jmp	#emit_opdata
not_mcount
		'' $c80 == cycleh (high cycle counter)
		cmp	immval, #$80 wz
	if_nz	jmp	#illegalinstr
		mov	opdata, getcth_pat
		setd	opdata, rd
		jmp	#emit_opdata
		
		'' here's where we do our non-standard registers
		''
		'' BC0 - BCF are vectored through
		'' a table at the start of memory
		''
		''
		
		'' BC0 == UART
not_standard
		cmp	func3, #$B wz	' is it one of ours?
	if_nz	jmp	#illegalinstr
	
		cmp	immval, #$1C0 wcz
	if_b	jmp	#not_vector
		cmp	immval, #$1CF wcz
	if_a	jmp	#not_vector

		'' here's the vector read/write code
		'' if there is a read (rd not x0) then get
		'' the value into pb first by calling the
		'' input vector
		'' for a write (rs1 not x0) then copy that to
		'' pb (or'ing or and'ing if necessary) and
		'' then calling the output vector
		''   the full sequence will look like
		''     call #\<csrvector_read>
		''     mov  rd, pb
		''     mov  pb, rs1 ' or and, or or
		''     call #\<csrvector_write>
		and	immval, #$f
		shl	immval, #3	' point to read vector
		add	immval, ##@csr_vectors
		
		'' if rd is x0, then skip the read
		cmp	rd, #0 wz
	if_z	jmp	#skip_csr_read
		andn	csrvec_read_instr, jit_loc_mask
		or	csrvec_read_instr, immval
		setd	csrvec_read_instr+1, rd
		mov	jit_instrptr, #csrvec_read_instr
		call	#emit2

skip_csr_read
		'' if rs1 is x0, skip any writes
   		cmp	rs1, #0 wz
	if_z	ret
		add	immval, #4	' move to write vector	
		'' implement write
		andn	csrvec_write_instr+1, jit_loc_mask
		or	csrvec_write_instr+1, immval
  		sets	csrvec_write_instr, rs1
		mov	jit_instrptr, #csrvec_write_instr
		jmp	#emit2		' return from there to caller

not_vector
		jmp	#illegalinstr

		' enter with ptrb holding pc
illegal_instr_error
		mov	uart_str, ##@illegal_instruction_msg
		call	#ser_str
		mov	uart_num, ptrb
		call	#ser_hex
die
		jmp	#die

		
		' create a checksum of memory
		' (uart_num, info2) are checksum
		' pa = start of mem block
		' pb = end of mem block
update_checksum
		rdbyte	temp, pa	' x := word[ptr]
		add	uart_num, temp	' c0 += x
		add	info2, uart_num	' c1 += x
		add	pa, #1 		' ptr += 2
		cmp	pa, pb wz
	if_ne	jmp	#update_checksum
		ret

		alignl
reg_buf
		long	0[32]
reg_buf_end

debug_print
		mov	uart_num, #0	' c0 := 0
		mov	info2, #0	' c1 := 0
		loc	pa, #\@__riscv_start	' ptr := PROGBASE
		loc	pb, #\TOP_OF_MEM
		call	#update_checksum

		' now merge in x0-x31
		loc	pa, #reg_buf
		loc	pb, #reg_buf_end
		
		setq	#31
		wrlong	x0, pa
		call	#update_checksum

		and	uart_num, ##$FFFF
		and	info2, ##$FFFF
		shl	info2, #16
		add	uart_num, info2
		call	#ser_hex

		mov	uart_char, #"@"
		call	#ser_tx
		mov	uart_num, ptrb
		call	#ser_hex

		mov	uart_str, ##@chksum_msg
		jmp	#ser_str

boot_msg
		byte	"RiscV P2 JIT (trace cache version)", 13, 10, 0
chksum_msg
		byte    "=memory chksum", 13, 10, 0
illegal_instruction_msg
		byte	"*** ERROR: illegal instruction at: ", 0
hex_buf
		byte  0[8], 0

		alignl

hub_pinsetinstr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		'' RISC-V has store value in rs2
		'' pin number in rs1
		'' adjust immediate for instruction format
		andn	immval, #$1f
		or	immval, rd
		'' isolate the precise function
		mov	func2, immval
		shr	func2, #10
		and	func2, #3
		and	immval, #$1ff
		mov	func3, #0
		cmp	rs1, #x0 wz	' is there a pin offset at all?
	if_z	mov	dest, immval
	if_z	bith	func3, #IMM_BITNUM
	if_z	jmp	#.do_op

		'' do we have to add an offset to the register
		cmp   immval, #0 wz
	if_z	mov	dest, rs1	' use rs1 as the pin value
	if_z	jmp   	#.do_op
		andn	locptra, jit_loc_mask
		or	locptra, immval
		sets	addptra, rs1
#ifdef OPTIMIZE_PTRA		
		neg	ptra_reg, #1
#endif		
		mov	jit_instrptr, #locptra
		call	#emit1
		mov	jit_instrptr, #addptra
		call	#emit1
		mov	dest, #ptra	' use ptra as the pin value	
.do_op
		' now the actual pin instruction
		' rs2 contains the value to write to the pin
		' dest contains the pin number
		' opdata contains a template like and yy, xx
		' func has the immediate flag
		shr	 opdata, #9 	     ' get instruction pattern into the src bits
		and	 opdata, #$1ff
		or	 opdata, dirinstr    ' set bits for dir
		setd	 opdata, dest	     ' set pin to affect
		or	 opdata, func3
		
		'' depending on func2 we have some different operations
		'' 00 = store value 01 == store !value
		'' 10 = store rnd   11 == invert existing value
		'' low bit goes directly into instruction
		test   func2, #%01 wc
		muxc   opdata, #%01
		'' check for using value; if we do use it then we may need to do a bit test
		test	func2, #%10 wc     ' do we use the value
	if_c	or	opdata, #%110	    ' if not, emit dirrnd/dirnot
	if_c	jmp	#emit_opdata
		cmp	rs2, #0 wz	     ' is the value known to be 0?
	if_z	jmp	#emit_opdata

		'' if the value isn't known, emit a test #1 wc to get the value into c
		setd	testbit_instr, rs2	' test the bit in the rs2 register
		mov	jit_instrptr, #testbit_instr
		call	#emit1
		or	opdata, #%10		' emit dirc/dirnc
		jmp	#emit_opdata

hub_wrpininstr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		'' RISC-V has store value in rs2
		'' adjust immediate for instruction format
		andn	immval, #$1f
		or	immval, rd
		'' upper 2 bits of immval control function
		mov	func2, immval
		shr	func2, #10
		and	func2, #3
		alts	func2, #wrpin_table
		mov	opdata, 0-0
		test	opdata, ##$3ffff wz	' if it's a jmp #illegalinstr
	if_nz	jmp	#emit_opdata
		and	immval, #$1ff wz
	if_z	mov	dest, rs1     ' use rs1 as the pin value directly
	if_z	jmp	#.skip_imm
		andn	locptra, jit_loc_mask
		or	locptra, immval
		sets	addptra, rs1
		mov	dest, #ptra		' use ptra as the pin value
.skip_imm
		setd	opdata, rs2
		sets	opdata, dest
		jmp	#emit_opdata

		''
		'' read pin data instructions
		''
hub_rdpininstr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		'' upper 2 bits of immval control function
		mov	func2, immval
		shr	func2, #10
		and	func2, #3
		alts	func2, #rdpin_table
		mov	opdata, 0-0
		and	immval, #$1ff wz
		'' check for nonzero pin offset
	if_z	jmp	#.skip_imm
		'' pin is non-zero: for now this is illegal
		'' (eventually we want to add the offset to
		'' the pin base)
		jmp    #illegalinstr
.skip_imm
		' never write to x0
		cmp	rd, #0 wz
	if_z	mov	rd, #temp
		' for func2 == 0 we need the testp instruction
		cmp	func2, #0 wz
	if_nz	jmp	#.skip_testp
		setd	testpin_instr, rs1
		mov	jit_instrptr, #testpin_instr
		call	#emit1
.skip_testp
		test	opdata, #$1ff wz
	if_z	sets	opdata, rs1
		test	opdata, ##($1ff<<9) wz	' check dest field
	if_z	setd	opdata, rd
		jmp	#emit_opdata
		
hub_coginitinstr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		shr	immval, #5	' skip over rs2
		mov	func2, immval
		and	func2, #3 wz
	if_nz	jmp	#illegalinstr

		' immval is actually rs3, which will go into setq
		shr	immval, #2

		' if rd is 0, then use "temp" instead
		cmp	rd, #0 wz
	if_z	mov	rd, #temp

		sets	coginit_pattern, rs1
		setd	coginit_pattern+1, immval
		sets	coginit_pattern+2, rs2
		setd	coginit_pattern+3, rd
		
		mov	jit_instrptr, #coginit_pattern
		mov	pb, #4
		jmp	#jit_emit

hub_singledestinstr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		cmp	rd, #0 wz
	if_z	mov	rd, #temp
		call	#emit_mov_rd_rs1
		sets	singledest_pat, immval
		setd	singledest_pat, rd
		setd	singledest_pat+1, rd
		mov	jit_instrptr, #singledest_pat
		testb	immval, #31 wc wc
		bitc	singledest_pat, #20 ' set C bit on instruction
	if_nc	jmp	#emit1
		testb	immval, #30 wc
	if_nc	jmp	#emit1
		jmp	#emit2
hub_stdinstr
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	opdata, jit_cond_mask
		shr	immval, #5
		and	immval, #$7f
		shl	immval, #2
		setr	opdata, immval
		cmp	rd, rs1 wz
	if_nz	call	#emit_mov_rd_rs1
		setd	opdata, rd
		sets	opdata, rs2
		jmp	#emit_opdata
		
		'' privileged instruction compilation code
hub_syspriv
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		cmp	rd, #0 wz
	if_nz	jmp	#illegalinstr
		cmp	immval, #0 wz
	if_z	jmp	#compile_ecall
		cmp	immval, #1 wz
	if_z	jmp	#compile_ebreak
		andn	immval, #$1f
		cmp	immval, #%0001001_00000 wz
	if_z	jmp	#compile_sfence
		jmp	#illegalinstr

compile_sfence
		ret	' for now, do nothing
compile_ebreak
		jmp	#illegalinstr	' someday make this different
compile_ecall
		mov	opdata, imp_illegal
		andn	opdata, jit_loc_mask
		or	opdata, ##@ecall_func
		jmp	#emit_opdata

		''
		'' atomic operations
		''
hub_compile_atomic
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		cmp	func3, #2 wz	' check width
	if_nz	jmp	#illegalinstr	' only 32 bit wide supported
		'' calculate new func3
		mov	func3, opdata
		shr	func3, #29
		and	func3, #7
		mov	func2, opdata
		shr	func2, #27
		and	func2, #3 wz	' check for lr/sc
	if_z	jmp	#do_atomic_op
		cmp	func3, #0 wz	' for remaining operations, func3 must be 0
	if_nz	jmp	#illegalinstr
		cmp	func2, #1 wz
	if_z	jmp	#do_amoswap
		cmp	func2, #2 wz
	if_z	jmp	#do_lr
do_sc
		mov	func3, #10
		jmp	#do_atomic_op
do_amoswap
		mov	func3, #8
		jmp	#do_atomic_op
do_lr
		mov	func3, #9
do_atomic_op
		shl	func3, #2	' convert to long index
		add	func3, ##@atomic_op_table
		rdlong	opdata, func3		' get the call instruction to use
		jmp	#handle_plain_call

atomic_op_table
		call	#\imp_amoadd	' 0
		call	#\imp_amoxor	' 1
		call	#\imp_amoor	' 2
		call	#\imp_amoand	' 3
		call	#\imp_amomin	' 4
		call	#\imp_amomax	' 5
		call	#\imp_amominu	' 6
		call	#\imp_amomaxu	' 7
		call	#\imp_amoswap	' 8
		call	#\imp_lr	' 9
		call	#\imp_sc	' 10

imp_amoadd
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		add	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amoxor
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		xor	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amoor
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		or	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amoand
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		and	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amomax
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		fges	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amomin
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		fles	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amomaxu
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		fge	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amominu
.lock_mem
		locktry	#ATOMIC_LOCK wc
  if_nc		jmp	#.lock_mem
  		rdlong	rd, rs1
		fle	rs2, rd
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
  _ret_		andn	valid_reservation, #1

imp_amoswap
.lock_mem
		locktry	#ATOMIC_LOCK wc
    if_nc	jmp	#.lock_mem
  		rdlong	rd, rs1
		wrlong	rs2, rs1
		lockrel	#ATOMIC_LOCK
    _ret_	andn	valid_reservation, #1

imp_lr
		locktry	#ATOMIC_LOCK wc
		rdlong	rd, rs1
  _ret_		bitc	valid_reservation, #0

imp_sc
		bitl	valid_reservation, #0 wcz	' carry set to original value of bit 0
    if_c	wrlong	rs2, rs1
    		lockrel	#ATOMIC_LOCK
    _ret_	wrnc	rd				' return 0 if valid_reservation was 1

		''
		''
		'' code for compiling compressed instructions
		''
hub_compressed_instr
		sub	ptrb, #2	' adjust for compressed instruction
		andn	opcode, SIGNWORD wz
	if_z	jmp	#c_illegalinstr
		mov	temp, opcode
		mov	dest, opcode
		shr	dest, #13
		and	dest, #7
		and	temp, #3
		shl	temp, #3
		or	dest, temp	' dest now contains opcode | func3
		shl	dest, #2
		add	dest, ##@rvc_jmptab
		jmp	dest

rvc_jmptab
		jmp	#c_addi4spn	' 00 000
		jmp	#c_illegalinstr	' 00 001
		jmp	#c_lw		' 00 010
		jmp	#c_illegalinstr	' 00 011
		jmp	#c_illegalinstr	' 00 100
		jmp	#c_illegalinstr	' 00 101
		jmp	#c_sw		' 00 110
		jmp	#c_illegalinstr	' 00 111

		jmp	#c_addi		' 01 000
		jmp	#c_jal		' 01 001
		jmp	#c_li		' 01 010
		jmp	#c_lui		' 01 011
		jmp	#c_math		' 01 100
		jmp	#c_j		' 01 101
		jmp	#c_beqz		' 01 110
		jmp	#c_bnez		' 01 111

		jmp	#c_slli		' 10 000
		jmp	#c_illegalinstr	' 10 001
		jmp	#c_lwsp		' 10 010
		jmp	#c_illegalinstr	' 10 011
		jmp	#c_mv		' 10 100
		jmp	#c_illegalinstr	' 10 101
		jmp	#c_swsp		' 10 110
		jmp	#c_illegalinstr	' 10 111

c_addi4spn
		mov	rd, opcode
		shr	rd, #2
		and	rd, #7
		add	rd, #x8
		mov	rs1, #x2
		mov	immval, #0
		testb	opcode, #5 wc
		bitc	immval, #3
		testb	opcode, #6 wc
		bitc	immval, #2
		testb	opcode, #7 wc
		bitc	immval, #6
		testb	opcode, #8 wc
		bitc	immval, #7
		testb	opcode, #9 wc
		bitc	immval, #8
		testb	opcode, #10 wc
		bitc	immval, #9
		testb	opcode, #11 wc
		bitc	immval, #4
		testb	opcode, #12 wc
		bitc	immval, #5
		abs	immval	wc
	if_nc	mov	opdata, adddata
	if_c	mov	opdata, subdata
#ifdef OPTIMIZE_CMP_ZERO
		mov	zcmp_reg, rd
		bith	opdata, #WZ_BITNUM
#endif		
		bith	opdata, #IMM_BITNUM
		jmp	#continue_imm

c_addi
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f wz
	if_z	jmp	#hub_emit_nop
		mov	immval, opcode
		testb	immval, #12 wc
		muxc	immval, #$80
		shl	immval, #24
		sar	immval, #26
		abs	immval wc
	if_nc	mov	opdata, adddata
	if_c	mov	opdata, subdata
#ifdef OPTIMIZE_CMP_ZERO
		mov	zcmp_reg, rd
		bith	opdata, #WZ_BITNUM
#endif		
		bith	opdata, #IMM_BITNUM
		setd	opdata, rd
		sets	opdata, immval
		mov	jit_instrptr, #opdata
		jmp	#emit1

c_li
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f wz
	if_z	jmp	#hub_emit_nop
		mov	immval, opcode
		shr	immval, #2
		and	immval, #$1f
		testb	opcode, #12 wc
		bitc	immval, #5
		signx	immval, #5
		abs	immval wc
	if_nc	mov	opdata, mov_pat
	if_c	mov	opdata, negdata
		bith	opdata, #IMM_BITNUM
		setd	opdata, rd
		sets	opdata, immval
		mov	jit_instrptr, #opdata
		jmp	#emit1
		
c_mv
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f wz
	if_z	jmp	#c_illegalinstr		' actually should be C_EBREAK
		mov	rs2, opcode
		shr	rs2, #2
		and	rs2, #$1f wz
	if_z	jmp	#c_jr
		' c_mv or c_add
		testb	opcode, #12 wc
	if_c	mov	opdata, adddata
	if_nc	mov	opdata, mov_pat
		sets	opdata, rs2
		setd	opdata, rd
#ifdef OPTIMIZE_CMP_ZERO
	'	bitl	opdata, #WZ_BITNUM
	if_c	mov	zcmp_reg, rd             ' only for add 
	'	neg	zcmp_reg, #1
#endif
		mov	jit_instrptr, #opdata
		jmp	#emit1

		' jump and/or jalr to rd
c_jr
		' if jalr, then
		' emit code to save ptrb in x1
		testb	opcode, #12 wc
#ifdef AUTO_INLINE		
	if_c	neg	ra_reg, #1
#endif	
	if_c	mov	immval, ptrb
	if_c	mov    	dest, #x1
	if_c	call   	#emit_mvi

		' generate code to copy final destination into ptrb
		sets	imp_jalr_nooff, rd
		mov	jit_instrptr, #imp_jalr_nooff
		call	#emit1
#ifdef AUTO_INLINE
		cmp	rd, ra_reg wz
	if_z	tjnf	ra_val, #c_skip_call
#endif
		' now generate the branch
		mov	jit_condition, #$f
		jmp	#jit_emit_indirect_branch
#ifdef AUTO_INLINE
c_skip_call
		mov	ptrb, ra_val
		ret
#endif

c_jal		' emit code to save ptrb in x1
#ifdef AUTO_INLINE
		mov	ra_reg, #1
		mov	ra_val, ptrb
#endif		
		mov    immval, ptrb
		mov    dest, #x1
		call   #emit_mvi
#ifdef AUTO_INLINE		
		mov	rd, #0
#endif		
		'' fall through
c_j
		mov	immval, opcode
		shr	immval, #2
		andn	immval, #1
		testb	opcode, #2 wc
		bitc	immval, #5
		testb	opcode, #6 wc
		bitc	immval, #7
		testb	opcode, #7 wc
		bitc	immval, #6
		testb	opcode, #8 wc
		bitc	immval, #10
		testb	opcode, #9 wc
		bitc	immval, #8
		testb	opcode, #10 wc
		bitc	immval, #9
		testb	opcode, #11 wc
		bitc	immval, #4
		testb	opcode, #12 wc
		bitc	immval, #11
		signx	immval, #11
		sub	immval, #2
#ifdef AUTO_INLINE
		add	ptrb, immval
		ret
#else		
		add	immval, ptrb
		mov	jit_branch_dest, immval
		mov	jit_condition, #$f
		jmp	#jit_emit_direct_branch
#endif		
c_lui
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f wz
	if_z	jmp	#hub_emit_nop
		cmp	rd, #2 wz
	if_z	jmp	#c_addi16sp
	
		mov	immval, opcode
		shr	immval, #2
		and	immval, #$1f
		shl	immval, #12
		testb	opcode, #12 wc
		bitc	immval, #17	' copy sign bit to bit 17
		signx	immval, #17
		mov	dest, rd
		jmp	#emit_mvi
		
c_addi16sp
		mov	immval, #0
		testb	opcode, #2 wc
		bitc	immval, #5
		testb	opcode, #3 wc
		bitc	immval, #7
		testb	opcode, #4 wc
		bitc	immval, #8
		testb	opcode, #5 wc
		bitc	immval, #6
		testb	opcode, #6 wc
		bitc	immval, #4
		testb	opcode, #12 wc
		bitc	immval, #9
		signx	immval, #9
'		mov	rd, #x2		' rd was already set to x2
		mov	rs1, #x2
		abs	immval wc
	if_nc	mov	opdata, adddata
	if_c	mov	opdata, subdata
		bith	opdata, #IMM_BITNUM		
#ifdef OPTIMIZE_CMP_ZERO
		bith	opdata, #WZ_BITNUM
		mov	zcmp_reg, rd
#endif		
		jmp	#continue_imm

c_swsp
		mov	rd, opcode
		shr	rd, #2
		and	rd, #$1f
		mov	opdata, swlongdata
		mov	immval, opcode
		' bits 7-12 of immval contain imm[5:2|7:6]
		shr	immval, #9
		and	immval, #$f
		shl	immval, #2
		testb	opcode, #7 wc
		bitc	immval, #6
		testb	opcode, #8 wc
		bitc	immval, #7
		mov	rs1, #x2
		mov	func3, #2
#ifdef OPTIMIZE_SETQ_RDLONG
		cmp	immval, #4 wcz
	if_be	jmp	#hub_ldst_common
		cmp	immval, #63 wcz
	if_a	jmp	#hub_ldst_common

		'' check for a chain of swsp instructions with
		'' decrementing offsets and incrementing registers
		mov	dest, opcode		
		sub	dest, #$1fc wc
	if_c	jmp	#hub_ldst_common
		mov	temp, dest
		and	temp, ##$e003
		cmp	temp, ##$c002 wz
	if_nz	jmp	#hub_ldst_common
		rdword	temp2, ptrb
		cmp	dest, temp2 wz
	if_nz	jmp	#hub_ldst_common
		mov	temp, temp2

		'' OK, temp2 *might* be an appropriate instruction for
		'' pairing
		'' so basically we want to emit a sequence like:
		''
		'' mov dummy+31, rd
		'' mov dummy+30, rd+1
		'' ...
		'' mov dummy+C, rd +N
		'' mov ptra, x2
		'' add ptra, #immval-4*N
		'' setq #N
		'' wrlong dummy+C, ptra(immval-4*N)
		'' sub ptra, #immval-4*N
		''
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	ioptr, #$1ef
		mov	func2, #0	' use func2 for extra value for setq
		sets	mov_pat, rd
		setd	mov_pat, ioptr
		mov	jit_instrptr, #mov_pat
		call	#emit1
emit_next_swsp_mov
		add	ptrb, #2
		add	rd, #1
		sub	ioptr, #1
		sets	mov_pat, rd
		setd	mov_pat, ioptr
		mov	jit_instrptr, #mov_pat
		call	#emit1
		sub	immval, #4 wz
		add	func2, #1
	if_z	jmp	#end_swsp_sequence
		cmp	func2, #15 wz
	if_z	jmp	#end_swsp_sequence
		mov	opcode, temp2
		mov	dest, opcode
		sub	dest, #$1fc wc
	if_c	jmp	#end_swsp_sequence
		rdword	temp2, ptrb
		cmp	dest, temp2 wz
	if_nz	jmp	#end_swsp_sequence
		mov	temp, dest
		and	temp, ##$e003
		cmp	temp, ##$c002 wz
	if_z	jmp	#emit_next_swsp_mov

end_swsp_sequence
#ifdef OPTIMIZE_PTRA
		cmp	ptra_reg, #x2 wz
	if_nz	mov	ptra_reg, #x2
	if_nz	sets	mov_to_ptra, #x2
	if_nz	mov	jit_instrptr, #mov_to_ptra
	if_nz	call	#emit1
#else
		sets	mov_to_ptra, #x2
		mov	jit_instrptr, #mov_to_ptra
		call	#emit1
#endif
		mov	temp, addptra
		bith	temp, #IMM_BITNUM
		sets	temp, immval
		mov	jit_instrptr, #temp
		call	#emit1
		
		rdlong	temp, #@setq_instr	' setq #0
		setd	temp, func2
		mov	jit_instrptr, #temp
		call	#emit1

		' now emit wrlong
		bith	opdata, #IMM_BITNUM
		sets	opdata, #%1000_00000 ' mode for ptra[0]
		setd	opdata, ioptr
		mov	rd, #0		' do not erase ra info
		call	#emit_opdata

		mov	temp, subptra
		bith	temp, #IMM_BITNUM
		sets	temp, immval
		mov	jit_instrptr, #temp
		jmp	#emit1
#else
		jmp	#hub_ldst_common
#endif

c_lwsp
		mov	func3, #2
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f wz
	if_z	jmp	#hub_emit_nop
		mov	immval, opcode
		shr	immval, #4
		and	immval, #7
		shl	immval, #2
		testb	opcode, #2 wc
		bitc	immval, #6
		testb	opcode, #3 wc
		bitc	immval, #7
		testb	opcode, #12 wc
		bitc	immval, #5
		mov	opdata, ldlongdata
		mov	rs1, #x2

#ifdef OPTIMIZE_SETQ_RDLONG
		' check for a sequence of ldsw x, N(sp)
		' where x is increasing and N decreasing;
		' this is something gcc generates
		cmp	rd, #2 wcz
	if_be	jmp	#hub_ldst_common
		cmp	immval, #4 wcz
	if_be	jmp	#hub_ldst_common
		cmp	immval, #64 wcz
	if_ae	jmp	#hub_ldst_common
	
		mov	dest, opcode
		add	dest, #$70
		rdword	temp2, ptrb
		cmp	dest, temp2 wz
	if_nz	jmp	#hub_ldst_common
		mov	temp, dest
		and	temp, ##$e003
		cmp	temp, ##$4002 wz
	if_nz	jmp	#hub_ldst_common

		' the load sequence is going to look like:
		' add	ptra, #immval-4*n
		' setq #N
		' rdlong $1e0, ptra[0] ' cannot use offset on setq+rdlong
		' sub	ptra, #immval-4*N
		' mov rd+N, $1e0
		' mov rd+N-1, $1e1
		' ...
		' mov rd, $X
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	ioptr, #$1e0
		mov	func2, #0	' use func2 to hold count for setq
emit_next_lwsp_item
		add	ptrb, #2
		add	rd, #1
		add	ioptr, #1
		sub	immval, #4 wc
		add	func2, #1
	if_c	jmp	#end_lwsp_sequence
		cmp	func2, #15 wz
	if_z	jmp	#end_lwsp_sequence
		mov	opcode, temp2
		mov	dest, opcode
		add	dest, #$70
		rdword	temp2, ptrb
		cmp	dest, temp2 wz
	if_nz	jmp	#end_lwsp_sequence
		mov	temp, dest
		and	temp, ##$e003
		cmp	temp, ##$4002 wz
	if_z	jmp	#emit_next_lwsp_item

end_lwsp_sequence
#ifdef OPTIMIZE_PTRA
		cmp	ptra_reg, #x2 wz
	if_nz	mov	ptra_reg, #x2
	if_nz	sets	mov_to_ptra, #x2
	if_nz	mov	jit_instrptr, #mov_to_ptra
	if_nz	call	#emit1
#else
		sets	mov_to_ptra, #x2
		mov	jit_instrptr, #mov_to_ptra
		call	#emit1
#endif
		mov	temp, addptra
		bith	temp, #IMM_BITNUM
		sets	temp, immval
		mov	jit_instrptr, #temp
		call	#emit1

		rdlong	temp, #@setq_instr	' setq #0
		setd	temp, func2
		mov	jit_instrptr, #temp
		call	#emit1

		' now emit wrlong
		sets	opdata, #%1000_00000 ' SUB mode for ptra[0]
		bith	opdata, #IMM_BITNUM
		setd	opdata, #$1e0
		call	#emit_opdata

		mov	temp, subptra
		bith	temp, #IMM_BITNUM
		sets	temp, immval
		mov	jit_instrptr, #temp
		call	#emit1
		
		' and the moves
		mov   ioptr, #$1e0
lwsp_move_loop
		mov	rs1, ioptr
		call	#emit_mov_rd_rs1
		add	ioptr, #1
		sub	rd, #1
		djnf	func2, #lwsp_move_loop
		
'		jmp	#illegalinstr
		ret
#else
		jmp	#hub_ldst_common
#endif

c_sw
		mov	opdata, swlongdata
		jmp	#c_lwswcommon
c_lw
		mov	opdata, ldlongdata
c_lwswcommon
		mov	rd, opcode
		shr	rd, #2
		and	rd, #7
		add	rd, #x8
		mov	rs1, opcode
		shr	rs1, #7
		and	rs1, #7
		add	rs1, #x8
		
		mov	immval, opcode
		shr	immval, #10
		and	immval, #7
		shl	immval, #3
		testb	opcode, #5 wc
		bitc	immval, #6
		testb	opcode, #6 wc
		bitc	immval, #2
		mov	func3, #2
		jmp	#hub_ldst_common
		
c_slli
		mov	rd, opcode
		shr	rd, #7
		and	rd, #$1f wz
	if_z	jmp	#hub_emit_nop
		mov	immval, opcode
		shr	immval, #2
		and	immval, #$1f
		mov	opdata, shldata
		bith	opdata, #IMM_BITNUM
#ifdef OPTIMIZE_CMP_ZERO
		bith	opdata, #WZ_BITNUM
		mov	zcmp_reg, rd
#endif		
		sets	opdata, immval
		setd	opdata, rd
		mov	jit_instrptr, #opdata
		jmp	#emit1

c_math
#ifdef OPTIMIZE_CMP_ZERO
		neg	zcmp_reg, #1
#endif		
		mov	rd, opcode
		shr	rd, #7
		mov	dest, rd	' selects actual function
		and	rd, #7
		add	rd, #x8
		mov	rs1, rd
		mov	opdata, sardata
		and	dest, #$18 wz
	if_z	mov	opdata, shrdata
		cmp	dest, #$18 wz
	if_z	jmp	#c_xtra
		cmp	dest, #$10 wz
	if_z	mov	opdata, anddata
	
		mov	immval, opcode
		shr	immval, #2
		and	immval, #$1f
		testb	opcode, #12 wc
		bitc	immval, #5
		signx	immval, #5
		bith	opdata, #IMM_BITNUM
		jmp	#continue_imm

c_xtra
		mov	rs2, opcode
		shr	rs2, #2
		mov	dest, rs2
		and	rs2, #7
		add	rs2, #x8
		mov	opdata, anddata	' assume choice 11
		and	dest, #$18 wz
	if_z	mov	opdata, subdata
		cmp	dest, #$08 wz
	if_z	mov	opdata, xordata
		cmp	dest, #$10 wz
	if_z	mov	opdata, ordata
		setd	opdata, rd
		sets	opdata, rs2
#ifdef OPTIMIZE_CMP_ZERO
		bith	opdata, #WZ_BITNUM
		mov	zcmp_reg, rd
#endif		
		mov	jit_instrptr, #opdata
		jmp	#emit1
	
		' the two branch instructions can share implementation,
		' they just differ in condition code
c_beqz
c_bnez
		testb	opcode, #13 wc
	if_nc	mov	jit_condition, #$a  ' if_z
	if_c	mov	jit_condition, #$5  ' if_nz
		mov	opdata, cmpdata
		mov	rs1, opcode
		shr	rs1, #7
		and	rs1, #7
		add	rs1, #x8
		mov	immval, #0
		testb	opcode, #2 wc
		bitc	immval, #5
		testb	opcode, #3 wc
		bitc	immval, #1
		testb	opcode, #4 wc
		bitc	immval, #2
		testb	opcode, #5 wc
		bitc	immval, #6
		testb	opcode, #6 wc
		bitc	immval, #7
		testb	opcode, #10 wc
		bitc	immval, #3
		testb	opcode, #11 wc
		bitc	immval, #4
		testb	opcode, #12 wc
		bitc	immval, #8
		signx	immval, #8
		' emit compare
		setd	opdata, rs1
		sets	opdata, #x0
		mov	jit_instrptr, #opdata
#ifdef OPTIMIZE_CMP_ZERO
		cmp	rs1, zcmp_reg wz
	if_nz	mov	zcmp_reg, rs1
	if_nz	call	#emit1
#else	
		call	#emit1
#endif
		' add in PC relative offset
		add	immval, ptrb
		sub	immval, #2
		
		mov	jit_branch_dest, immval
		jmp	#jit_emit_direct_branch

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' System call facilities
'' called with:
''  x17 == function to use
''  x10, x11, x12, ... = arguments
''  x10 == result (negative for error)
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#define ENOENT  2
#define EIO     5
#define EBADF   9
#define ENOMEM 12
#define EACCES 13
#define ENFILE 23
#define ENOTTY 25
#define ENOSYS 88

#define ECALL_CLOSE     57
#define ECALL_READ      63
#define ECALL_WRITE     64
#define ECALL_FSTAT	80
#define ECALL_EXIT	93
#define ECALL_TIMES	153
#define ECALL_GETTIMEOFDAY 169
#define ECALL_OPEN 1024
#define ECALL_TIME 1062

#define ECALL_FPU	4000
#define ECALL_CLKSET    4001

ecall_func
		mov	x16, x17
		sub	x16, ##ECALL_FPU wcz
	if_ae	jmp	#syscall_fpu	
		cmp	x17, #ECALL_WRITE wz
	if_z	jmp	#syscall_write
		cmp	x17, #ECALL_READ wz
	if_z	jmp	#syscall_read
		cmp	x17, #ECALL_GETTIMEOFDAY wz
	if_z	jmp	#syscall_gettimeofday
		cmp	x17, #ECALL_EXIT wz
	if_z	jmp	#syscall_exit
		cmp	x17, ##ECALL_CLKSET wz
	if_z	jmp	#syscall_clkset
		neg	x10, #ENOSYS
		ret
syscall_write
		' x10 == handle (0=stdin, 1=stdout, 2=stderr)
		' x11 == data buf
		' x12 == count of bytes
		cmp	x10, #3 wcz
	if_ae	neg	x10, #EBADF
	if_ae	ret
		mov	x10, x12	wz
	if_z	ret
writelp
		rdbyte	dest, x11
		add	x11, #1
		cmp	dest, #10 wz	' LF?
	if_z	mov	uart_char, #13
	if_z	call	#ser_tx
		mov	uart_char, dest
		call	#ser_tx
		djnz	x12, #writelp
		ret

		alignl
termio_struct
termio_iflag	long	0
termio_oflag	long	0
termio_cflag	long	0
termio_lflag	long	$02	' ICANON == 0x2
termio_line	byte	0
termio_cc
		byte	3	' 0: VINTER = ^C
		byte	27	' 1: VQUIT = ^\
		byte	8	' 2: VERASE = backspace
		byte	21	' 3: VKILL = ^U erases line
		byte	4	' 4: VEOF = ^D
		byte	5	' 5: VTIME
		byte	6	' 6: VMIN
		
syscall_read
		' x10 == handle (0=stdin, 1=stdout, 2=stderr)
		' x11 == data buf
		' x12 == count of bytes
		' x5 == t0 used to hold lflags
		' x6 == t1 used to hold new char
		' x7 == t2 used to hold
		cmp	x10, #3 wcz
	if_ae	neg	x10, #EBADF
	if_ae	ret
		mov	x10, #0
		loc	ptrb, #termio_struct
		rdlong	x5, ptrb[3]	' x5 has lflags
		test	x5, #2 wz	' check for canonical mode
	if_nz	jmp	#do_canonical_read

do_noncanon_read
		call	#\ser_rx
		cmps	uart_char, #0 wcz
	if_b	ret
		wrbyte	uart_char, x11
		add	x11, #1
		add	x10, #1
		djnz	x12, #do_noncanon_read
		ret
do_canonical_read
		call	#\ser_rx
		cmps	uart_char, #0 wcz
	if_b	jmp	#do_canonical_read
	
		cmp	uart_char, #4	wz ' check for ^D
	if_z	ret

		call	#\ser_tx
		
		cmp	uart_char, #13 wz
	if_z	mov	uart_char, #10
	if_z	call	#\ser_tx
	
		cmp	uart_char, #8	wz ' check for backspace
	if_z	jmp	#do_backspace
		wrbyte	uart_char, x11
		add	x11, #1
		add	x10, #1
		cmp	uart_char, #10 wz
	if_nz	djnz	x12, #do_canonical_read
		ret
do_backspace
		cmp	x10, #0 wz	' any bytes in buffer?
	if_nz	sub	x11, #1
	if_nz	sub	x10, #1
		jmp	#do_canonical_read
		
syscall_exit
		cogid	temp
		cogstop	temp

		'' x10 == pointer to timeval struct
		''   32 bits time_t
		''   32 bits microseconds
syscall_gettimeofday
		mov	dest, cycleh
		getct	x12
		cmp	dest, cycleh wz
	if_nz	jmp	#syscall_gettimeofday

		'' now (dest, x12) is 64 bit cycle counter
		'' convert to seconds
		'' read frequency from $14
		rdlong	temp, #$14    	' get frequency into temp
		qdiv	temp, ##1000000
		getqx	temp2		' get frequency / 1000000 into temp2
		
		setq	dest
		qdiv	x12, temp
		getqx	dest		' dest is seconds
		getqy	x12		' x12 is remainder cycles

		qdiv	x12, temp2
		getqx	x12	 	' x12 is microseconds
		wrlong	dest, x10
		add	x10, #4
		wrlong	x0, x10		' time_t is 64 bits
		add	x10, #4
		wrlong	x12, x10
	_ret_	mov	x10, #0

syscall_clkset
		mov	pa, x10		' first parameter is clock mode
		mov	pb, x11		' second is clock frequency
		jmp	#ser_clkset
		
#ifdef OPTIMIZE_CMP_ZERO
cmp_zero_debug
		mov	uart_num, opdata
		call	#ser_hex
		mov	uart_num, rd
		call	#ser_hex
		mov	uart_num, rs1
		call	#ser_hex
		mov	uart_num, rs2
		call	#ser_hex
		call	#ser_nl
		jmp	#illegalinstr
#endif		
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' floating point routines
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#include "Double.spin2"

syscall_fpu
		fle	x16, #10
		jmprel	x16
		jmp	#@FAdd
		jmp	#@FSub
		jmp	#@FMul
		jmp	#@FDiv
		jmp	#@DAdd
		jmp	#@DSub
		jmp	#@DMul
		jmp	#@DDiv
		jmp	#@FSqrt
		jmp	#@DSqrt
		jmp	#@__err

__err
		neg	x10, #1
		ret

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' cache memory
		orgh
		alignl
#ifdef LVL2_CACHE_TAGS
lvl2_tags
		long	0[CACHE_TAG_SIZE]
#endif
#ifdef TOTAL_SIZE

START_OF_CACHE
		long 0
		orgh TOTAL_SIZE
END_OF_CACHE

#else

# ifdef CACHE_SIZE
START_OF_CACHE
		byte	0[CACHE_SIZE]
END_OF_CACHE
# endif

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
		orgh
		alignl
here
		' we have to pad to a 32 byte boundary; for some
		' reason PNut for P2 pads output this way, and fastspin does
		' as well. But we cannot afford to have any
		' padding come after the final label
		'byte $ff[ ((@@@here+31) & !31) - @@@here ]
		byte $ff[ ((@here+255) & !255) - @here ]
#endif

__riscv_start
