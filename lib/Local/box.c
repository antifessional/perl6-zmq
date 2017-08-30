
#include <stdio.h> 
#include <string.h> 
#include <stdlib.h>

#ifndef ALTER
#define ALTER 0
#endif

#ifndef VERBOSE
#define VERBOSE 0
#endif


void *box_carray( void *array, int index) {
    return (void *)(((long)array) + index);
} 
