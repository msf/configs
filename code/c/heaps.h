#ifndef _HEAPS_H_
#define _HEAPS_H_

typedef struct {
    unsigned size;
    unsigned heap_size;
    int *a;
} heap_t;

heap_t * maxheap_new(int *array, unsigned size);

int maxheap_popmax(heap_t *heap);
int maxheap_max(heap_t *heap);

int maxheap_increase_key(heap_t *heap, unsigned i, int value);
int maxheap_insert(heap_t *heap, int value);


heap_t * minheap_new(int *array, unsigned size);

int minheap_popmin(heap_t *heap);
int minheap_min(heap_t *heap);

int minheap_decrease_key(heap_t *heap, unsigned i, int value);
int minheap_insert(heap_t *heap, int value);
#endif // _HEAPS_H_
