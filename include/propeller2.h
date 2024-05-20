#ifndef PROPELLER2_H
#define PROPELLER2_H

#include <stdint.h>

#pragma once
//
// definitions for Control Status Registers for the P2 Risc-V platform
//

// these are the CSR numbers for the P2 hardware registers
#define _DIRA_CSR 0x7fa
#define _DIRB_CSR 0x7fb
#define _OUTA_CSR 0x7fc
#define _OUTB_CSR 0x7fd
#define _INA_CSR  0x7fe
#define _INB_CSR  0x7ff

#define _UART_CSR 0xBC0
#define _WAITCYC_CSR 0xBC1
#define _DBGPRNT_CSR 0xBC2
#define _MILLIS_CSR 0xBC3
#define _UART_STATUS_CSR 0xBC4

#define _CNT_CSR  0xC00
#define _CNTH_CSR 0xC80

#define _X__(x) #x
#define _X_(x) _X__(x)

// read data from a CSR
#define _csr_read(csr)						\
({								\
	register unsigned long __v;				\
	__asm__ __volatile__ ("csrr %0, " _X_(csr)             \
			      : "=r" (__v));			\
	__v;							\
})

// write val to the CSR (csr = val)
#define _csr_write(csr, val)					\
({								\
	unsigned long __v = (unsigned long)(val);		\
	__asm__ __volatile__ ("csrw " _X_(csr) ", %0"		\
			      : : "rK" (__v));			\
})

// read and then write the CSR (csr = val, return old csr)
#define _csr_read_write(csr, val)				\
({								\
	unsigned long __v = (unsigned long)(val);		\
	__asm__ __volatile__ ("csrrw %0, " _X_(csr) ", %1"      \
			      : "=r" (__v) : "rK" (__v));	\
	__v;							\
})

// set bits in a CSR (does "csr |= val")
#define _csr_set(csr, val)					\
({								\
	unsigned long __v = (unsigned long)(val);		\
	__asm__ __volatile__ ("csrs " _X_(csr) ", %0"		\
			      : : "rK" (__v));			\
})

// clear bits in a CSR (does "csr &= ~val"; that is, 1 bits in val
// indicate where we want to clear bits in the csr)
#define _csr_clear(csr, val)					\
({								\
	unsigned long __v = (unsigned long)(val);		\
	__asm__ __volatile__ ("csrc " _X_(csr) ", %0"		\
			      : : "rK" (__v));			\
})

/*
 * common types
 */

// cartesian coordinates
typedef struct _cartesian {
   int32_t x, y;
} cartesian_t;

// polar coordinates
typedef struct _polar {
   uint32_t r, t;
} polar_t;

// 64 bit counter
typedef struct _counter64 {
    uint32_t low, high;
} counter64_t;

/*
 * P2 32 Bit Clock Mode (see macros below to construct)
 *
 *      0000_000e_dddddd_mmmmmmmmmm_pppp_cc_ss
 *
 *   e          = XPLL (0 = PLL Off, 1 = PLL On)
 *   dddddd     = XDIV (0 .. 63, crystal divider => 1 .. 64)
 *   mmmmmmmmmm = XMUL (0 .. 1023, crystal multiplier => 1 .. 1024)
 *   pppp       = XPPP (0 .. 15, see macro below)
 *   cc         = XOSC (0 = OFF, 1 = OSC, 2 = 15pF, 3 = 30pF)
 *   ss         = XSEL (0 = rcfast, 1 = rcslow, 2 = XI, 3 = PLL)
 */

// macro to calculate XPPP (1->15, 2->0, 4->1, 6->2 ... 30->14) ...
#define XPPP(XDIVP) ((((XDIVP)>>1)+15)&0xF)  

// macro to combine XPLL, XDIV, XDIVP, XOSC & XSEL into a 32 bit CLOCKMODE ...
#define CLOCKMODE(XPLL,XDIV,XMUL,XDIVP,XOSC,XSEL) ((XPLL<<24)+((XDIV-1)<<18)+((XMUL-1)<<8)+(XPPP(XDIVP)<<4)+(XOSC<<2)+XSEL) 

// macro to calculate final clock frequency ...
#define CLOCKFREQ(XTALFREQ, XDIV, XMUL, XDIVP) ((XTALFREQ)/(XDIV)*(XMUL)/(XDIVP))

#define _cnt() _csr_read(_CNT_CSR)
#define _cnth() _csr_read(_CNTH_CSR)
#define _waitcnt(tim) _csr_write(_WAITCYC_CSR, tim)
#define _waitms(ms) _csr_write(_MILLIS_CSR, ms)

#define _getcnt() _cnt()

// NOTE:
// CUSTOM0 opcode is 0x0b (2<<2)+3
// CUSTOM1 opcode is 0x2b (10<<2)+3

// TESTP
#define _pinr(pin)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_0, 7, %0, 0(%1)" \
                              : "=r"(v) : "r"(pin) );        \
        v;                                                  \
    })

// Spin calls "DRVxx" "PINxx" (except PINF is FLTL)
#define _pinw(pin, value)                             \
    ({                                                  \
        unsigned long v = value;                         \
        __asm__ __volatile__ (".insn s CUSTOM_0, 2, %0, 0x000(%1)" \
                              : : "r"(v), "r"(pin) );             \
        v;                                                  \
    })

#define _pinnot(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, -0x400(%0)" \
                              : : "r"(pin) );             \
    })

#define _pinrnd(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, -0x800(%0)" \
                              : : "r"(pin) );             \
    })

#define _pinl(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, 0x000(%0)" \
                              : : "r"(pin) );             \
    })
#define _pinh(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, 0x400(%0)" \
                              : : "r"(pin) );             \
    })

#define _fltl(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 3, x0, 0x000(%0)" \
                              : : "r"(pin) );             \
    })
#define _flth(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 3, x0, 0x400(%0)" \
                              : : "r"(pin) );             \
    })

#define _outl(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 4, x0, 0x000(%0)" \
                              : : "r"(pin) );             \
    })
#define _outh(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 4, x0, 0x400(%0)" \
                              : : "r"(pin) );             \
    })

#define _dirl(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 5, x0, 0x000(%0)" \
                              : : "r"(pin) );             \
    })
#define _dirh(pin) \
    ({                                                  \
        __asm__ __volatile__ (".insn s CUSTOM_0, 5, x0, 0x400(%0)" \
                              : : "r"(pin) );             \
    })

// Spin's name for "fltl" is "pinf"
#define _pinf(p) _fltl(p)

// Smart pin functions
#define _wrpin(pin, value)                              \
    ({                                                  \
        unsigned long v = value;                         \
        __asm__ __volatile__ (".insn s CUSTOM_0, 6, %0, 0x000(%1)" \
                              : : "r"(v), "r"(pin) );             \
        v;                                                  \
    })
#define _wxpin(pin, value)                             \
    ({                                                  \
        unsigned long v = value;                         \
        __asm__ __volatile__ (".insn s CUSTOM_0, 6, %0, 0x400(%1)" \
                              : : "r"(v), "r"(pin) );             \
        v;                                                  \
    })
#define _wypin(pin, value)                             \
    ({                                                  \
        unsigned long v = value;                         \
        __asm__ __volatile__ (".insn s CUSTOM_0, 6, %0, -0x800(%1)" \
                              : : "r"(v), "r"(pin) );             \
        v;                                                  \
    })

#define _rdpin(pin)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_0, 7, %0, 0x400(%1)" \
                              : "=r"(v) : "r"(pin) );        \
        v;                                                  \
    })

#define _akpin(pin)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_0, 7, x0, -0x800(%0)" \
                              : : "r"(pin) );        \
        v;                                                  \
    })

// coginit
#define ANY_COG 0x10

#define _coginit(a, b, c)                                  \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn r CUSTOM_1, 0, 0, %0, %1, %2, %3" \
                              : "=r"(v) : "r"(a), "r"(b), "r"(c)  );    \
        v;                                                  \
    })

// Catalina uses _cogstart_PASM instead of _coginit
#define _cogstart_PASM(a, b, c) _coginit(a, b, c)

#define _cognew(a, b) _coginit(ANY_COG, a, b)

#define _cogid()                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 1(%0)" \
                              : "=r"(v) );    \
        v;                                                  \
    })

#define _cogchk(id)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, -2048 + 1(%1)" \
                              : "=r"(v) : "r"(id) );           \
        (v < 0) ? v : 0;                                      \
    })

#define _cogstop(a)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 3(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _locknew()                                      \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, -2048+4(%0)" \
                              : "=r"(v)  );    \
        v;                                                  \
    })

#define _lockret(a)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 5(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _locktry(a)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, -2048+6(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        (v < 0) ? v : 0;                                \
    })
#define _lockrel(a)                                     \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, -2048+7(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })


#define _rnd()                                          \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 27(%0)" \
                              : "=r"(v)  );    \
        v;                                              \
    })

#define _waitx(a)                                       \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 31(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _rev(a)                                         \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 0x69(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _popcount(a)                                   \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn r CUSTOM_1, 2, 0x3d, %0, %0, %1" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _encod(a)                                       \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn r CUSTOM_1, 2, 0x3c, %0, %0, %1" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _clz(aorig) ({ unsigned long a = (aorig); (a == 0) ? 32 : 31 - _encod(a); })

#define _clockfreq() (*(unsigned int *)0x14)
#define _clockmode() (*(unsigned int *)0x18)

#define _waitus(u) _waitx((u)*(_clockfreq()/1000000))
#define _waitms(u) _waitx((u)*(_clockfreq()/1000))

// cordic routines
#define _getqx()                                        \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 0x18(%0)" \
                              : "=r"(v)  );    \
        v;                                              \
    })
#define _getqy()                                        \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 0x18(%0)" \
                              : "=r"(v)  );    \
        v;                                              \
    })

#define _qlog(a)                                       \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 0xe(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

#define _qexp(a)                                       \
    ({                                                  \
        unsigned long v;                                \
        __asm__ __volatile__ (".insn i CUSTOM_1, 1, %0, 0xf(%1)" \
                              : "=r"(v) : "r"(a)  );    \
        v;                                                  \
    })

extern void _clkset(unsigned int mode, unsigned int freq);

#endif
