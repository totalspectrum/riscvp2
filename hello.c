#include <stdio.h>
#include <propeller2.h>

//#define testfunc(i) _popcount(i)
#define testfunc(i) _clz(i)

void main()
{
    int i = 0;
    for(;;) {
        printf("test(0x%x) = %x\r\n", i, testfunc(i));
        _waitx(20000);
        i++;
    }
}
