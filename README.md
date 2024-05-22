# riscvp2

This project provides a way to use RISC-V tools to build Parallax Propeller P2 binaries.

## Overview

This is a project that turns a RISC-V toolchain into a Propeller P2 toolchain. It's tuned for GCC right now, but in principle could be used on clang or other compilers.

It works by adding a Just-In-Time (JIT) compiler from RISC-V instructions to P2 instructions to the front of the RISC-V binary. This means that we can execute the code at full speed on the P2, except that there is some latency for the initial compilation. Also, large programs which exceed the size of the instruction cache can run into slowdowns. In practice though performance seems to be good; in fact, GCC with riscvp2 outperforms all other C compilers for the P2 on many benchmarks!

The JIT compiler accepts the rv32imac variant of the RISC-V instruction set, together with some P2 specific custom instructions. See `P2_Internals.md` for details.

### propeller2.h

The file `include/propeller2.h` defines many useful macros for the P2, for doing things like pin manipulation and timing.

## Using Binary Releases

In the "Releases" there are some .zip files for various platforms. If you download one of these, you'll be able to use the toolchain to build applications for the P2 right away.

### License

Note that gcc is distributed under the GNU General Public License (see the file COPYING.GPL). In the binary distributions, I have not modified the actual GNU compiler in any way, and am merely conveying the compiled binaries I downloaded from:

https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack

This release has been tested with xpack-riscv-none-elf-gcc-13.2.0-2, but should work with other releases too.

See that web page for directions on how to obtain source and re-build the compiler, if you wish to do so (it is not necessary for use on the P2!)

The P2 specific modifications are under the MIT License, and source code for these are found at:

https://github.com/totalspectrum/riscvp2

No changes to GPL code are required; the P2 modifications involve adding some linker scripts and object files.

### Installation

There is no GUI or installer provided; all of the tools are plain command line tools.

Unzip the downloaded file somewhere convenient (lets call it $FOO) and add $FOO/riscvp2/bin to your path. That's it!


## Building C Applications

Now you should be ready to build. To create a P2 compatible ELF file, do:
```
   riscv-none-embed-gcc -T riscvp2.ld -Os -o hello.elf hello.c
```

The `-T riscvp2.ld` says to link for the P2. Other options are as usual for GCC.

The output file will claim to be a RISC-V ELF file, but at its very beginning will be the P2 JIT compiler, which is P2 code. This may be loaded directly by `loadp2`, e.g.:
```
   loadp2 hello.elf -b230400 -t
```
Default baud rate is 230400 baud, and default clock speed is 160 MHz. These may be overridden as usual by loadp2's -f and -PATCH flags.

It's also possible to convert the ELF file to a plain binary, which may be loaded by any P2 loader:
```
   riscv-none-embed-objcopy -O binary hello.elf hello.binary
```

### Building C++ Applications

Basically the same as building C applications, but use `riscv-none-embed-g++ -T riscvp2.ld` instead of `riscv-none-embed-gcc -T riscvp2.ld`.

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

## Building from Source

If you prefer to build the P2 parts of the code from source, you may do this by checking out this repository and following the steps below.

### Download a Toolchain

First, obtain a RISC-V toolchain. In an earlier iteration of this project I built the standard RISC-V toolchain myself from source. But I've since switched to the xpack toolchain, which comes in convenient binary form from:

https://github.com.xpack-dev-tools/riscv-none-embed-gcc-xpack/releases/latest.

You may also start from one of the pre-built binary releases for riscvp2.

#### Linux

For my x64 Linux machine I downloaded `xpack-riscv-none-embed-gcc-8.3.0-1.2-linux-x64.tar.gz` and extracted it to /opt. For ease of use I made a symbolic link `ln -s /opt/xpack-riscv-none-embed-gcc-8.3.0-1.2 /opt/riscv`

You can change the name to suit your taste; just edit the `TOOLROOT` definition in the Makefile.

#### Windows

For Windows I downloaded xpack-riscv-none-embed-gcc-8.3.0-1.2-win32-x64.zip.


### Edit the Makefile

Edit the Makefile so that the `FASTSPIN`, `TOOLROOT`, and `TOOLPREFIX` variables are set up for your system. The defaults for TOOLROOT and TOOLPREFIX will be fine if you used the gnu-mcu-eclipse toolchain and moved it to `/opt/riscv-none-gcc` as described above. Otherwise `TOOLROOT` should be the root directory for the toolchain, and `TOOLPREFIX` the prefix used for binaries (this may be `riscv-unknown-elf` or `riscv-none-embed`). In the end `$(TOOLROOT)/bin/$(TOOLPREFIX)-gcc` should be the path to the RISC-V gcc.

### Installation of P2 code

Once you've edited the Makefile as described above, you should be able to do `make install` to copy the necessary files to the RISC-V toolchain directory and then be ready to build and run P2 applications as described above.

