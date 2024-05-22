#include <stdio.h>
#include <propeller2.h>

//#define TEST_SERIN
#define TESTBLINK

//#define testfunc(i) _popcount(i)
//#define testfunc(i) _clz(i)

#ifdef TESTBLINK
int testfunc(int i)
{
    int basepin = 57;

#if 1
    // new way to do it, using macros in propeller2.h
    _pinl(56);
    _pinnot(57);
    _pinnot(58);
#else
    // direct access to the RISC-V P2 extension instructions
    // drive pin 56 low
    __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, 56(x0)");
    // toggle pin 57
    __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, -0x400(%0)" : : "r"(basepin));
    // toggle pin 58
    __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, -0x3ff(%0)" : : "r"(basepin));
#endif
    return i;
}
#endif
#ifdef TEST_SERIN
int testfunc(int i)
{
    return _csr_read(_UART_STATUS_CSR);
}
#endif

void main()
{
    int i = 0;
    int r;
    for(;;) {
        r = testfunc(i);
        printf("test(0x%x) = %x\r\n", i, r);
        _waitms(1000);
        i++;
    }
}
