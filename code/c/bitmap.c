#include <stdlib.h>
#include <string.h>

#include "bitmap.h"

bitmap_t * bitmap_new(unsigned bit_count)
{
    unsigned map_size;
    bitmap_t *msk = malloc(sizeof(bitmap_t));
    if(!msk)
        return NULL;

    msk->bit_count = bit_count;

    map_size = (bit_count / 8) + 1;
    msk->map = (char *) calloc(map_size, sizeof(char));
    if(!msk->map) {
        free(msk);
        return NULL;
    }
    msk->map_size = map_size;

    return msk;
}

void bitmap_free(bitmap_t *bitmap)
{
    if( !bitmap  || !bitmap->map)
        return ;

    free(bitmap->map);
    free(bitmap);
}

int bitmap_set(bitmap_t *bitmap, unsigned pos)
{
    if( !bitmap  || !bitmap->map)
        return -1;

    unsigned n = pos / 8;
    unsigned off = pos % 8;
    bitmap->map[n] |= 1 << off;
    return 0;
}

int bitmap_unset(bitmap_t *bitmap, unsigned pos)
{
    if( !bitmap  || !bitmap->map)
        return -1;

    unsigned n = pos / 8;
    unsigned off = pos % 8;
    bitmap->map[n] &= ~(1 << off);
    return 0;
}

int bitmap_isset(bitmap_t *bitmap, unsigned pos)
{
    if( !bitmap  || !bitmap->map)
        return -1;

    unsigned n = pos / 8;
    unsigned off = pos % 8;
    return ( bitmap->map[n] >> off ) & 1 ;
}

void bitmap_setall(bitmap_t *m)
{
    if( !m || !m->map)
        return ;
    memset(m->map, 0xff, m->map_size);
}

void bitmap_unsetall(bitmap_t *m)
{
    if( !m || !m->map)
        return ;
    memset(m->map, 0, m->map_size);
}




