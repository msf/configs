
typedef struct {
    char *map;
    unsigned bit_count;
    unsigned map_size;
} mask_t;


/* creates a new (all bits unset) mask */
mask_t * mask_new(unsigned bit_count);

void mask_free(mask_t *mask);
int mask_set(mask_t *mask, unsigned pos);
int mask_unset(mask_t *mask, unsigned pos);
int mask_isset(mask_t *mask, unsigned pos);

void mask_unsetall(mask_t *mask);
void mask_setall(mask_t *mask);
