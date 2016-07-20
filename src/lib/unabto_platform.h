#ifndef _UNABTO_PLATFORM_H_
#define _UNABTO_PLATFORM_H_

#include <stdio.h>
#include "unabto_platform_types.h"

/**
* Socket related definitions
*/
#define NABTO_INVALID_SOCKET -1

/**
* Time related definitions
*/
#define NABTO_SET_TIME_FROM_ALIVE 0
#define nabtoMsec2Stamp

/**
* Logging related definitions
*/
#define NABTO_LOG_BASIC_PRINT(loglevel, cmsg) \
do {                                          \
    printf cmsg;                              \
    printf("\n");                             \
} while(0)

#endif
