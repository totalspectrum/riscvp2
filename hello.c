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
    
    // drive pin 56 low
    __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, 56(x0)");
    // toggle pin 57
    __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, -0x400(%0)" : : "r"(basepin));
    // toggle pin 58
    __asm__ __volatile__ (".insn s CUSTOM_0, 2, x0, -0x3ff(%0)" : : "r"(basepin));
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
        i++;
        for(int j = 0; j < 100; j++) {
            _waitx(160000000/100);
        }
    }
}
