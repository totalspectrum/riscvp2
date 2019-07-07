#
# Makefile for various aspects of the RISC-V to P2 conversion
#

# config: change these to suit your setup
# FASTSPIN is the path to your fastspin program
FASTSPIN=/home/ersmith/Parallax/spin2cpp/build/fastspin -q
TOOLROOT=/opt/riscv-none-gcc
TOOLPREFIX=riscv-none-embed-

AS=$(TOOLROOT)/bin/$(TOOLPREFIX)as
CC=$(TOOLROOT)/bin/$(TOOLPREFIX)gcc

#
# build 2 versions of the trace code:
#   p2trace.bin: normal version with 32KB cache
#   p2lut.bin:   compact version with cache in LUT
#

P2SRCS=riscvtrace_p2.spin jit/jit_engine.spinh jit/util_serial.spin2

all: rvp2.o rvp2_lut.o

rvp2.o: rvp2.s p2trace.bin

rvp2_lut.o: rvp2_lut.s p2lut.bin

p2trace.bin: $(P2SRCS)
	$(FASTSPIN) -2 -o $@ riscvtrace_p2.spin

p2lut.bin: $(P2SRCS)
	$(FASTSPIN) -2 -DUSE_LUT_CACHE -o $@ riscvtrace_p2.spin

clean:
	rm -f *.bin *.o
