#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bitmap.h"

int bitmap_test1(bitmap_t *m, unsigned len)
{
    unsigned i;
    for(i = 0; i < len; i++) {
        if(bitmap_isset(m, i)) {
            printf("ERROR 1 in: %d\n", i);
            return 1;
        }
    }
    return 0;
}

int bitmap_test2(bitmap_t *m, unsigned len)
{
    unsigned i;
    bitmap_setall(m);
    for(i = 0; i < len; i++) {
        if(!bitmap_isset(m, i)) {
            printf("ERROR 2 in: %d\n", i);
            return 1;
        }
    }
    return 0;
}

int bitmap_test3(bitmap_t *m, unsigned len)
{
    unsigned i;
    bitmap_unsetall(m);
    for(i = 0; i < len; i++) {
        if(bitmap_isset(m, i)) {
            printf("ERROR 3 in: %d\n", i);
            return 1;
        }
    }
    return 0;
}

int bitmap_test4(bitmap_t *m, unsigned len)
{
    unsigned i = len / 2;
    bitmap_unsetall(m);
    bitmap_set(m, i);
    if( bitmap_isset(m, i-1) || bitmap_isset(m, i+1) || !bitmap_isset(m, i) ) {
        printf("ERROR 4 in: %d\n", i);
        return 1;
    }
    return 0;
}

int bitmap_test(unsigned len)
{
    int ok = 0;
    bitmap_t *m;

    m = bitmap_new(len);

    if( bitmap_test1(m, len) ||
        bitmap_test2(m, len) ||
        bitmap_test3(m, len) ||
        bitmap_test4(m, len) ) {
        ok = 1;
    }
    bitmap_free(m);
    return ok;
}


int main(int argc, char *argv[])
{
    unsigned len, i;

    len = 1 << atoi(argv[1]);
    for(i = 2 ; i < len; i <<= 1)
        printf("%d -> %d\n",i, bitmap_test(i));

}
