#
# Makefile for various aspects of the RISC-V to P2 conversion
#

# config: change these to suit your setup
# FASTSPIN is the path to your fastspin program
FASTSPIN=/home/ersmith/Parallax/spin2cpp/build/fastspin -q

# TOOLROOT and TOOLPREFIX are for the RISC-V toolchain
# These are for a self-built standard RISC-V toolchain in /opt/riscv
#TOOLROOT=/opt/riscv
#TOOLPREFIX=riscv32-unknown-elf

# These are for the gnu mcu eclipse toolchain as described in README.md
TOOLROOT=/opt/riscv-none-gcc
TOOLPREFIX=riscv-none-embed

# these defaults should work well
BINPREFIX=$(TOOLROOT)/bin/$(TOOLPREFIX)-
LIBROOT=$(TOOLROOT)/$(TOOLPREFIX)/lib
INCLUDE=$(TOOLROOT)/$(TOOLPREFIX)/include

AS=$(BINPREFIX)as
CC=$(BINPREFIX)gcc
CXX=$(BINPREFIX)g++

#
# build 2 versions of the trace code:
#   p2trace.bin: normal version with 32KB cache
#   p2lut.bin:   compact version with cache in LUT
#

P2SRCS=riscvtrace_p2.spin jit/jit_engine.spinh jit/util_serial.spin2
LDSCRIPTS=riscvp2.ld riscvp2_lut.ld
ASMSCRIPTS=rvp2.s rvp2_lut.s

default:
	@echo "make install       -- install P2 files in RISC-V toolchain"
	@echo "make hello.binary  -- make C demo"
	@echo "make hello-c++.binary -- make C++ demo"

#
# install: make everything and copy to the toolchain
#          deletes the local .elf files because the new P2 code may
#          make them obsolete
#
EMUOBJS=rvp2.o rvp2_lut.o

install: $(EMUOBJS) $(LDSCRIPTS)
	cp $(EMUOBJS) $(LDSCRIPTS) $(LIBROOT)
	cp -r include/* $(INCLUDE)
	rm -f *.elf *.binary

# rules to build the linker scripts
riscvp2.ld: ldscript.templ
	sed "s^%LIBROOT%^$(LIBROOT)^g;s^%EMULATOR%^rvp2.o^g" < ldscript.templ > $@

riscvp2_lut.ld: ldscript.templ
	sed "s^%LIBROOT%^$(LIBROOT)^g;s^%EMULATOR%^rvp2_lut.o^g" < ldscript.templ > $@

# rules to build the assembly stubs that add the JIT RISC-V to P2 compiler
# at the start of binaries

rvp2.s: asm.templ p2trace.bin
	sed "s^%BINFILE%^p2trace.bin^g" < asm.templ > $@

rvp2_lut.s: asm.templ p2lut.bin
	sed "s^%BINFILE%^p2lut.bin^g" < asm.templ > $@

rvp2.o: rvp2.s p2trace.bin
	$(CC) -o $@ -c $<

rvp2_lut.o: rvp2_lut.s p2lut.bin
	$(CC) -o $@ -c $<

# the actual P2 JIT code, compiled via fastspin
p2trace.bin: $(P2SRCS)
	$(FASTSPIN) -2 -l -o $@ riscvtrace_p2.spin

p2lut.bin: $(P2SRCS)
	$(FASTSPIN) -2 -l -DUSE_LUT_CACHE -o $@ riscvtrace_p2.spin


# our demo programs
hello.elf: hello.c
	$(CC) -T riscvp2.ld -specs=nano.specs -Os -o $@ $<

hello.binary: hello.elf
	$(BINPREFIX)objcopy -O binary $< $@

hello-c++.elf: hello.cc
	$(CXX) -T riscvp2.ld -specs=nano.specs -Os -o $@ $<

hello-c++.binary: hello-c++.elf
	$(BINPREFIX)objcopy -O binary $< $@

clean:
	rm -f *.binary *.bin *.elf *.o *.p2asm *,lst $(LDSCRIPTS) $(ASMSCRIPTS)
