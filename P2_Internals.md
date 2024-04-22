# riscvp2 Internals

These are some notes on how riscvp2 works and some of the features that it makes available to programmers. You don't have to know these things to just compile C programs, but if you want to extend the system, program in assembly language, or just generally know what's happening, these notes will be helpful.

## RISC-V Emulation

riscvp2 mostly emulates the RV32IMAC architecture of RISC-V. That is, it supports the base 32 bit integer instructions (RV32I) with the M (multiply/divide), A (atomic operations) and C (compressed instructions) extensions. There are some caveats:

(1) Not all of the control status registers (CSRs) required by the RISC-V standard are implemented. I've just done the most commonly used ones (see below for details)

(2) The Atomic extension is not conformant. Reservations created by the `lr` instruction are only invalidated by other atomic operations such as `amoswap` and `sc`, and not by stores. This is an architectural issue; we simulate the atomics by locking/unlocking lock #15, and I didn't want to add the lock/unlock overhead around every store. In practice I think most applications relying on atomic memory access to a location will consistently use atomic operations on that location. Note that the atomic instructions really aren't tested, nor are they particularly useful since multiple threads are not supported yet.

## Custom Instructions

RISC-V is designed to be extensible, so riscvp2 takes advantage of that to create custom instructions for the P2.

The assembler has not been updated to include these new instructions yet, but fortunately the standard RISC-V assembler contains the `.insn` pseudo-op which may be used to create arbitrary instructions. Below I've written both a friendly mnemnoic form and the long `.insn` form for each instruction.

### Pin I/O

#### PINR

```
pinr rd, rs1
.insn i CUSTOM_0, 7, rd, 0(rs2)
```
Makes the pin whose value is in `rs2` an input, and reads one bit from it. The bit is stored in `rd`.

#### PINW

```
pinw rs1, rs2
.insn s CUSTOM_0, 2, rs1, IMM(rs2)
```
Makes the pin whose value is in `rs2` (adjusted by `IMM`) an output, and writes a new value to it. The new value depends on the value in `rs1` and the bits in the immediate value `IMM`, as follows:

If `IMM` is 0+OFF, writes the value in `rs1` to the pin.
If `IMM` is 0x400+OFF, writes the inverse of the value in `rs1` to the pin.
If `IMM` is -0x400+OFF, writes the inverse of the current pin value back to the pin
If `IMM` is -0x800+OFF, writes a random value to the pin.

where OFF is a 6 bit value giving the base pin number.

A number of interesting effects can be achieved. For example, to set a pin high (like the PASM `PINH` instruction) use `x0` for the source and `0x400` for the `IMM`; `x0` always contains 0, so inverting it will always write a 1.

Example: to create the equivalent of PASM `drvl #9` do:
```
.insn s CUSTOM_0, 2, x0, 9(x0)
```

#### DIRW

```
dirw rs1, rs2
.insn s CUSTOM_0, 5, rs1, IMM(rs2)
```
Sets the direction for the pin whose value is in `rs2` an output. Basically, this writes a bit to the DIRA or DIRB register, as appropriate, The new value depends on the value in `rs1` and the bits in the immediate value `IMM`, as follows:

If `IMM` is 0, writes the value in `rs1` to the appropriate bit in the DIR register
If `IMM` is 0x400, writes the inverse of the value in `rs1` to the approrpiate DIR register bit
If `IMM` is -0x400, inverts the current pin direction
If `IMM` is -0x800, writes a random value to the DIR register

### Smartpin Control

#### WRPIN

```
wrpin rs1, rs2
.insn s CUSTOM_0, 6, rs1, 0x000(rs2)
```
Writes `rs1` to the mode register of smart pin `rs2`, and acknowledges the smart pin.

#### WXPIN

```
wxpin rs1, rs2
.insn s CUSTOM_0, 6, rs1, 0x400(rs2)
```
Writes `rs1` to the X register of smart pin `rs2`, and acknowledges the smart pin.

#### WYPIN

```
wypin rs1, rs2
.insn s CUSTOM_0, 6, rs1, -0x800(rs2)
```
Writes `rs1` to the Y register of smart pin `rs2`, and acknowledges the smart pin.

#### RDPIN

```
rdpin rd, rs2
.insn i CUSTOM_0, 7, rd, 0x400(rs2)
```
Gets the smart pin result register Z of the pin specified by `rs2` into `rd`. Acknowledges the smart pin.

#### RQPIN

```
rqpin rd, rs2
.insn i CUSTOM_0, 7, rd, -0x800(rs2)
```
Gets the smart pin result register Z of the pin specified by `rs2` into `rd`. Does not acknowledge the smart pin.

### COG Control

```
coginit rd, rs1, rs2, rs3
.insn r CUSTOM_1 0, 0, rd, rs1, rs2, rs3
```
Starts a new COG.

```
cogid rd, rs1
.insn i CUSTOM_1 1, rd, 1(rs1)
```
Fetches the COG id of the currently executing COG into register `rd`. `rs1` is currently ignored, and for optimal performance should be set to be the same as `rd`.

```
cogstop rs1
.insn i CUSTOM_1, 1, rs1, 3(rs1)
```
Stops the COG whose ID is `rs1`.

### General P2 instructions

These are escapes to allow general P2 instructions to be executed. Some of them are used to implement the instructions listed above.

#### One Operand instructions

```
.insn i CUSTOM_1, 1, rd, <op>(rs1)
```
Executes the P2 instruction with opcode `0b1101011` (the block of single operand instructions beginning with HUBSET). The low 9 bits of <op> are placed in the S field to select the operation to perform. The D field is set to `rd`. Before the instruction, `rs1` is copied to `rd` to initialize it (if necessary).

#### Two Operand instructions

```
.insn r CUSTOM_1, 2, <op>, rd, rs1, rs2
````
Executes the P2 instruction with opcode <op> (a 7 bit value). The C, Z, and I bits are all set to 0, and the condition bits are set to all 1. The destination field is set to `rd` and the source field to `rs2`. Before the instruction `rs1` is moved into `rd` (if necessary).

## Resources used

The whole of COG and LUT memory in any COG running the RISC-V engine are used by the JIT compiler. (For now only one COG, COG 0, does this, but someday this may change).

The atomic instructions, including `lr` and `sc`, use lock 15.

When multiple CPUs are implemented, we will use lock 14 to control access to the CPU cache in HUB memory.

