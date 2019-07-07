# riscvp2

Convert RISC-V binaries to Parallax Propeller P2 binaries

## Overview

This is a project that turns a RISC-V toolchain into a Propeller P2 toolchain. It's tuned for GCC right now, but in principle could be used on clang or other compilers.

For now this is tested only on Linux machines, but I think it should work for Mac OS X and for Windows. The only tricky part is making sure that the path names are acceptable to Windows, but I think if everything is on one drive it should be OK.

## Directions

### Toolchain

First, obtain a RISC-V toolchain. In an earlier iteration of this project I built the standard RISC-V toolchain myself from source. But I've since switched to the GNU MCU Eclipse toolchain, which comes in convenient binary form from https://github.com/gnu-mcu-eclipse/riscv-none-gcc/releases/.

For my x64 Linux machine I downloaded `gnu-mcu-eclipse-riscv-none-gcc-8.2.0-2.2-20190521-0004-centos64.tgz` and extracted it to a local directory. The tools are buried in a slightly funny directory structure; we could work with that, but to simplify it I elimiinated a few layers, and moved:
```
./gnu-mcu-eclipse/riscv-none-gcc/8.2.0-2.2.2-20190521-004
```
to
```
/opt/riscv-none-gcc
```
You can change the name to suit your taste; just edit the `TOOLROOT` definition in the Makefile.

### Makefile

Edit the Makefile so that the `FASTSPIN`, `TOOLROOT`, and `TOOLPREFIX` variables are set up for your system. The defaults for TOOLROOT and TOOLPREFIX will be fine if you used the gnu-mcu-eclipse toolchain and moved it to `/opt/riscv-none-gcc` as described above. Otherwise `TOOLROOT` should be the root directory for the toolchain, and `TOOLPREFIX` the prefix used for binaries (this may be `riscv-unknown-elf` or `riscv-none-embed`). In the end `$(TOOLROOT)/bin/$(TOOLPREFIX)-gcc` should be the path to the RISC-V gcc.

### Installation of P2 code

Once you've edited the Makefile as described above, you should be able to do `make install` to copy the necessary files to the RISC-V toolchain directory.

## Building Applications

Now you should be ready to build. To create a P2 compatible ELF file, do:
```
   riscv-none-embed-gcc -T riscvp2.ld -Os -o hello.elf hello.c -lc -lgloss
```

The `-T riscvp2.ld` says to link for the P2. The `-lc` and `-lgloss` are necessary; `libgloss` contains the implementations for system calls, and if we don't include this after an explicit `-lc` the default link order will not find them.

You may want to also pass `-specs=nano.specs`. This uses a reduced version of the newlib C library ("nano-newlib") which still has most useful functionality but is much smaller.

None of the current loaders for P2 can load ELF files, so this must further be converted to binary:
```
   riscv-none-embed-objcopy -O binary hello.elf hello.binary
```
Now `hello.binary` may be run on the P2 eval board:
```
   loadp2 -SINGLE -b230400 hello.binary -t
```
