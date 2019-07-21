#include <stdio.h>
#include <propeller2.h>

//#define testfunc(i) _popcount(i)
//#define testfunc(i) _clz(i)

int testfunc(int i)
{
    int basepin = 57;
    
    // drive pin 56 low
    __asm__ __volatile__ (".insn sb CUSTOM_0, 2, x0, 56(x0)");
    // toggle pin 57
    __asm__ __volatile__ (".insn sb CUSTOM_0, 2, x0, -0x400(%0)" : : "r"(basepin));
    // toggle pin 58
    __asm__ __volatile__ (".insn sb CUSTOM_0, 2, x0, -0x3ff(%0)" : : "r"(basepin));
    return i;
}

void main()
{
    int i = 0;
    int r;
    for(;;) {
        r = testfunc(i);
        _waitx(160000000);
        printf("test(0x%x) = %x\r\n", i, r);
        i++;
    }
}
