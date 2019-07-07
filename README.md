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

Edit the Makefile so that the `FASTSPIN`, `TOOLROOT`, and `TOOLPREFIX` variables are set up for your system. The defaults for TOOLROOT and TOOLPREFIX will be fine if you used the gnu-mcu-eclipse toolchain and moved it to `/opt/riscv-none-gcc` as described above. Otherwise `TOOLROOT` should be the root directory for the toolchain, and `TOOLPREFIX` the prefix used for binaries (this may be `riscv-unknown-elf-` or `riscv-none-embed-`). In the end `$(TOOLROOT)/bin/$(TOOLPREFIX)gcc` should be the path to the RISC-V gcc.

