#
# Makefile for various aspects of the RISC-V to P2 conversion
#

# config: change these to suit your setup
# FASTSPIN is the path to your fastspin program
FASTSPIN=/home/ersmith/Parallax/spin2cpp/build/fastspin -q
TOOLROOT=/opt/riscv-none-gcc
TOOLPREFIX=riscv-none-embed

# these defaults should work well
BINPREFIX=$(TOOLROOT)/bin/$(TOOLPREFIX)-
LIBROOT=$(TOOLROOT)/$(TOOLPREFIX)/lib

AS=$(BINPREFIX)as
CC=$(BINPREFIX)gcc

#
# build 2 versions of the trace code:
#   p2trace.bin: normal version with 32KB cache
#   p2lut.bin:   compact version with cache in LUT
#

P2SRCS=riscvtrace_p2.spin jit/jit_engine.spinh jit/util_serial.spin2
EMUOBJS=rvp2.o rvp2_lut.o
LDSCRIPTS=riscvp2.ld riscvp2_lut.ld

default: $(EMUOBJS) $(LDSCRIPTS)

install: $(EMUOBJS) $(LDSCRIPTS)
	cp $^ $(LIBROOT)

riscvp2.ld: ldscript.templ
	sed "s^%LIBROOT%^$(LIBROOT)^g;s^%EMULATOR%^rvp2.o^g" < ldscript.templ > $@

riscvp2_lut.ld: ldscript.templ
	sed "s^%LIBROOT%^$(LIBROOT)^g;s^%EMULATOR%^rvp2_lut.o^g" < ldscript.templ > $@

rvp2.o: rvp2.s p2trace.bin
	$(CC) -o $@ -c $<

rvp2_lut.o: rvp2_lut.s p2lut.bin
	$(CC) -o $@ -c $<

p2trace.bin: $(P2SRCS)
	$(FASTSPIN) -2 -o $@ riscvtrace_p2.spin

p2lut.bin: $(P2SRCS)
	$(FASTSPIN) -2 -DUSE_LUT_CACHE -o $@ riscvtrace_p2.spin



hello.elf: hello.c
	$(CC) -T riscvp2.ld -o hello.elf hello.c -lc -lgloss

hello.binary: hello.elf
	$(BINPREFIX)objcopy -O binary $< $@

clean:
	rm -f *.binary *.bin *.o $(LDSCRIPTS)

