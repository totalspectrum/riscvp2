# riscvp2

Convert RISC-V binaries to Parallax Propeller P2 binaries

## Overview

This is a project that turns a RISC-V toolchain into a Propeller P2 toolchain. It's tuned for GCC right now, but in principle could be used on clang or other compilers.

For now this is tested only on Linux and Windows machines, but I think it should work for Mac OS X too.

## Directions

### Toolchain

First, obtain a RISC-V toolchain. In an earlier iteration of this project I built the standard RISC-V toolchain myself from source. But I've since switched to the GNU MCU Eclipse toolchain, which comes in convenient binary form from https://github.com/gnu-mcu-eclipse/riscv-none-gcc/releases/ or https://github.com.xpack-dev-tools/riscv-none-embed-gcc-xpack/releases/latest.

### Linux

For my x64 Linux machine I downloaded `gnu-mcu-eclipse-riscv-none-gcc-8.2.0-2.2-20190521-0004-centos64.tgz` and extracted it to a local directory. The tools are buried in a slightly funny directory structure; we could work with that, but to simplify it I eliminated a few layers, and moved:
```
./gnu-mcu-eclipse/riscv-none-gcc/8.2.0-2.2.2-20190521-004
```
to
```
/opt/riscv-none-gcc
```
You can change the name to suit your taste; just edit the `TOOLROOT` definition in the Makefile.

### Windows

For Windows I downloaded xpack-riscv-none-embed-gcc-8.3.0-1.2-win32-x64.zip.

### Makefile

Edit the Makefile so that the `FASTSPIN`, `TOOLROOT`, and `TOOLPREFIX` variables are set up for your system. The defaults for TOOLROOT and TOOLPREFIX will be fine if you used the gnu-mcu-eclipse toolchain and moved it to `/opt/riscv-none-gcc` as described above. Otherwise `TOOLROOT` should be the root directory for the toolchain, and `TOOLPREFIX` the prefix used for binaries (this may be `riscv-unknown-elf` or `riscv-none-embed`). In the end `$(TOOLROOT)/bin/$(TOOLPREFIX)-gcc` should be the path to the RISC-V gcc.

### Installation of P2 code

Once you've edited the Makefile as described above, you should be able to do `make install` to copy the necessary files to the RISC-V toolchain directory.

## Building C Applications

Now you should be ready to build. To create a P2 compatible ELF file, do:
```
   riscv-none-embed-gcc -T riscvp2.ld -Os -o hello.elf hello.c
```

The `-T riscvp2.ld` says to link for the P2. Other options are as usual for GCC.

### Command line options

#### -T linker script

There are several linker scripts installed:
```
riscvp2.ld:     uses HUB memory as cache, good for larger programs
riscvp2_lut.ld: uses LUT memory as cache, good for smaller programs
```

#### -specs

You may want to also pass `-specs=nano.specs`. This uses a reduced version of the newlib C library ("nano-newlib") which still has most useful functionality but is much smaller.

#### -Wl,-Tfastmath.ld

This is an option to link a faster floating point library, which uses P2 primitives. The code for this is invoked (for now) via `ecall`, but eventually the plan is to support RISC-V floating point instructions natively.

### Output

You'll either have to use a loader that understands ELF files (e.g. the one from my p2gcc fork) or else convert the ELF file to binary:
```
   riscv-none-embed-objcopy -O binary hello.elf hello.binary
```
Now `hello.binary` may be run on the P2 eval board:
```
   loadp2 -SINGLE -b230400 hello.binary -t
```

## Building C++ Applications

Basically the same as building C applications, but use `$(TOOLCHAIN)-g++` instead of `$(TOOLCHAIN)-gcc`.
