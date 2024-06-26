#
# Makefile for various aspects of the RISC-V to P2 conversion
#

# config: change these to suit your setup
# FLEXSPIN is the path to your fastspin program
FLEXSPIN=/home/ersmith/Parallax/spin2cpp/build/flexspin -q

# TOOLROOT and TOOLPREFIX are for the RISC-V toolchain
# These are for a self-built standard RISC-V toolchain in /opt/riscv-std-toolchain
#TOOLROOT=/opt/riscv-std-toolchain
#TOOLPREFIX=riscv32-unknown-elf

# Architecture: we support rv32imac, with the Zicsr extension
ARCH=-march=rv32imac_zicsr

# These are for the xpack toolchain as described in README.md
TOOLROOT=/opt/riscv
TOOLPREFIX=riscv-none-elf

# these defaults should work well
BINPREFIX=$(TOOLROOT)/bin/$(TOOLPREFIX)-
LIBROOT=$(TOOLROOT)/$(TOOLPREFIX)/lib
INCLUDE=$(TOOLROOT)/$(TOOLPREFIX)/include

AS=$(BINPREFIX)as $(ARCH)
CC=$(BINPREFIX)gcc $(ARCH)
CXX=$(BINPREFIX)g++ $(ARCH)

#
# build 3 versions of the trace code:
#   p2trace.bin: normal version with 32KB cache
#   p2lut.bin:   compact version with cache in LUT
#   p2flash.bin: version that can run code from flash
#

P2SRCS=riscvtrace_p2.spin2 jit/jit_engine.spinh jit/util_serial.spin2 Double.spin2 jit/util_flash.spin2
LDSCRIPTS=riscvp2.ld riscvp2_lut.ld riscvp2_flash.ld fastmath.ld
ASMSCRIPTS_GEN=rvp2.s rvp2_lut.s rvp2_flash.s
ASMSCRIPTS=$(ASMSCRIPTS_GEN)

default:
	@echo "make install       -- install P2 files in RISC-V toolchain"
	@echo "make hello.binary  -- make C demo"
	@echo "make hello-c++.binary -- make C++ demo"
	@echo "make MODE=_flash hello.elf  -- make C demo for flash"
	@echo "make MODE=_flash hello-c++.elf -- make C++ demo for flash"

#
# install: make everything and copy to the toolchain
#          deletes the local .elf files because the new P2 code may
#          make them obsolete
#
EMUOBJS=rvp2.o rvp2_lut.o rvp2_flash.o fastmath.o

install: $(EMUOBJS) $(LDSCRIPTS)
	cp $(EMUOBJS) $(LDSCRIPTS) $(LIBROOT)
	cp -r include/* $(INCLUDE)
	cp README.md $(TOOLROOT)/README_P2.md
	cp P2_Internals.md COPYING.GPL $(TOOLROOT)/
	rm -f *.elf *.binary

# rules to build the assembly stubs that add the JIT RISC-V to P2 compiler
# at the start of binaries

rvp2.s: asm.templ p2trace.bin
	sed "s^%BINFILE%^p2trace.bin^g" < asm.templ > $@

rvp2_lut.s: asm.templ p2lut.bin
	sed "s^%BINFILE%^p2lut.bin^g" < asm.templ > $@

rvp2_flash.s: asm.templ p2flash.bin
	sed "s^%BINFILE%^p2flash.bin^g" < asm.templ > $@

fastmath.o: fastmath.s
	$(CC) -o $@ -c $<

rvp2.o: rvp2.s p2trace.bin
	$(CC) -o $@ -c $<

rvp2_lut.o: rvp2_lut.s p2lut.bin
	$(CC) -o $@ -c $<

rvp2_flash.o: rvp2_flash.s p2flash.bin
	$(CC) -o $@ -c $<

# the actual P2 JIT code, compiled via flexspin
p2trace.bin: $(P2SRCS)
	$(FLEXSPIN) -2 -l -o $@ riscvtrace_p2.spin2

p2lut.bin: $(P2SRCS)
	$(FLEXSPIN) -2 -l -DUSE_LUT_CACHE -o $@ riscvtrace_p2.spin2

p2flash.bin: $(P2SRCS)
	$(FLEXSPIN) -2 -l -DFLASH_HIMEM=1 -o $@ riscvtrace_p2.spin2


# our demo programs
OPT ?= -Os

hello.elf: hello.c
	$(CC) -T riscvp2$(MODE).ld -specs=nano.specs $(OPT) -o $@ $<

hello.binary: hello.elf
	$(BINPREFIX)objcopy -O binary $< $@

hello-c++.elf: hello.cc
	$(CXX) -T riscvp2$(MODE).ld -specs=nano.specs $(OPT) -o $@ $<

hello-c++.binary: hello-c++.elf
	$(BINPREFIX)objcopy -O binary $< $@

clean:
	rm -f *.binary *.bin *.elf *.o *.p2asm *.lst $(ASMSCRIPTS_GEN)
