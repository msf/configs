
typedef struct {
    char *map;
    unsigned bit_count;
    unsigned map_size;
} bitmap_t;


/* creates a new (all bits unset) bitmap */
bitmap_t * bitmap_new(unsigned bit_count);

void bitmap_free(bitmap_t *bitmap);
int bitmap_set(bitmap_t *bitmap, unsigned pos);
int bitmap_unset(bitmap_t *bitmap, unsigned pos);
int bitmap_isset(bitmap_t *bitmap, unsigned pos);

void bitmap_unsetall(bitmap_t *bitmap);
void bitmap_setall(bitmap_t *bitmap);
