#ifndef _PROPELLER_H
#define _PROPELLER_H

#include <propeller2.h>

#define getcnt() _cnt()
#define getcnth() _cnth()
#define waitcnt(tim) _csr_write(_WAITCYC_CSR, tim)
#define getmillis() _csr_read(_MILLIS_CSR)

#define getpin(pin)	_pinr(pin)
#define setpin(pin, val) _pinw(pin, val)
#define togglepin(pin)	_pinnot(pin)
#define pinlow(pin) 	_pinl(pin)
#define pinhigh(pin)    _pinh(pin)

#define coginit(a, b, c) _coginit(a, b, c)
#define cognew(a, b)     _cognew(a, b)
#define cogstop(a)       _cogstop(a)

#define _clkfreq _clockfreq()

#endif
