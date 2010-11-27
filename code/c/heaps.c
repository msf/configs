#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include "heaps.h"

#define ASSERT_HEAP(heap)  { \
    if(!heap || !heap->a || heap->heap_size < 1) \
        return -1; \
};

static unsigned heap_parent( unsigned pos ) { return (pos-1)/2; }

static unsigned heap_left( unsigned pos ) { return pos*2 +1; }

static unsigned heap_right( unsigned pos ) { return pos*2 +2; }

static int heap_grow(heap_t *heap)
{

    unsigned size;
    int *tmp;
    /* if heap maxed out.. grow it! */
    if( heap->heap_size == heap->size ) {
        size = heap->size * 2;
        tmp = realloc(heap->a, size);
        if( tmp ) {
            heap->size = size;
            heap->a = tmp;
        } else
            return -1;
    }
    return 0;
}

static int maxheap_heapify(heap_t *heap, unsigned i)
{
    unsigned l = heap_left(i);
    unsigned r = heap_right(i);

    unsigned largest = 0;
    int t;

    ASSERT_HEAP(heap);
    if( l <= heap->heap_size && heap->a[l] > heap->a[i] )
        largest = l;
    else
        largest = i;


    if( r <= heap->heap_size && heap->a[r] > heap->a[largest] )
        largest = r;

    if( largest != i ) {
        t = heap->a[i];
        heap->a[i] = heap->a[largest];
        heap->a[largest] = t;

        return maxheap_heapify(heap, largest);
    }
    return 0;
}

/* create new heap from array of @size */
heap_t * maxheap_new(int *array, unsigned size)
{
    heap_t *heap = calloc(1, sizeof(heap_t));

    heap->size = size;
    if( array ) {
        heap->a = array;
        heap->heap_size = size;
    } else {
        heap->a = malloc(size*sizeof(int));
        heap->heap_size = 1;
        heap->a[0] = INT_MIN;
        heap->a[1] = INT_MIN;
        heap->a[2] = INT_MIN;
    }

    for(int i = heap->heap_size/2; i >= 0; i--) {
        maxheap_heapify(heap, i);
    }
    return heap;
}


/* returns the element of heap with largest key */
int maxheap_max(heap_t *heap)
{
    ASSERT_HEAP(heap);
    return heap->a[0];
}

/* remove and returns the element of heap with largest key */
int maxheap_popmax(heap_t *heap)
{
    ASSERT_HEAP(heap);

    int max = heap->a[0];
    heap->a[0] = heap->a[heap->heap_size];
    heap->heap_size -= 1;

    maxheap_heapify(heap, 0);
    return max;
}


int maxheap_increase_key(heap_t *heap, unsigned i, int value)
{
    ASSERT_HEAP(heap);
    if( value < heap->a[i]) {
        perror("maxheap_increase_key(): new value smaller then current!");
        return -1;
    }
    heap->a[i] = value;

    int tmp;
    unsigned parent = heap_parent(i);
    while( i > 0 && heap->a[parent] < heap->a[i]) {
        /* swap i & parent */
        tmp = heap->a[i];
        heap->a[i] = heap->a[parent];
        heap->a[parent] = tmp;

        /* go up the tree */
        i = parent;
        parent = heap_parent(i);
    }
    return 0;
}


int maxheap_insert(heap_t *heap, int value)
{
    ASSERT_HEAP(heap);

    int rc = heap_grow(heap);
    if(rc)
        return rc;

    heap->heap_size +=1;
    heap->a[ heap->heap_size ] = INT_MIN;

    return maxheap_increase_key(heap, heap->heap_size, value);
}


static int minheap_heapify(heap_t *heap, unsigned i)
{
    unsigned l = heap_left(i);
    unsigned r = heap_right(i);

    unsigned smallest = 0;
    int t;

    ASSERT_HEAP(heap);
    if( l <= heap->heap_size && heap->a[l] < heap->a[i] )
        smallest = l;
    else
        smallest = i;


    if( r <= heap->heap_size && heap->a[r] < heap->a[smallest] )
        smallest = r;

    if( smallest != i ) {
        t = heap->a[i];
        heap->a[i] = heap->a[smallest];
        heap->a[smallest] = t;

        return minheap_heapify(heap, smallest);
    }
    return 0;
}

/* create new heap from array of @size */
heap_t * minheap_new(int *array, unsigned size)
{
    heap_t *heap = calloc(1, sizeof(heap_t));

    heap->size = size;
    if( array ) {
        heap->a = array;
        heap->heap_size = size;
    } else {
        heap->a = malloc(size*sizeof(int));
        heap->heap_size = 1;
        heap->a[0] = INT_MAX;
        heap->a[1] = INT_MAX;
        heap->a[2] = INT_MAX;
    }

    for(int i = heap->heap_size/2; i >= 0; i--) {
        minheap_heapify(heap, i);
    }
    return heap;
}


/* returns the element of heap with largest key */
int minheap_min(heap_t *heap)
{
    ASSERT_HEAP(heap);
    return heap->a[0];
}

/* remove and returns the element of heap with largest key */
int minheap_popmin(heap_t *heap)
{
    ASSERT_HEAP(heap);

    int min = heap->a[0];
    heap->a[0] = heap->a[heap->heap_size];
    heap->heap_size -= 1;

    minheap_heapify(heap, 0);
    return min;
}


int minheap_decrease_key(heap_t *heap, unsigned i, int value)
{
    ASSERT_HEAP(heap);
    if( value > heap->a[i]) {
        perror("minheap_decrease_key(): new value bigger than current!");
        return -1;
    }
    heap->a[i] = value;

    int tmp;
    unsigned parent = heap_parent(i);
    while( i > 0 && heap->a[parent] > heap->a[i]) {
        /* swap i & parent */
        tmp = heap->a[i];
        heap->a[i] = heap->a[parent];
        heap->a[parent] = tmp;

        /* go up the tree */
        i = parent;
        parent = heap_parent(i);
    }
    return 0;
}


int minheap_insert(heap_t *heap, int value)
{
    ASSERT_HEAP(heap);

    int rc = heap_grow(heap);
    if(rc)
        return rc;

    heap->heap_size +=1;
    heap->a[ heap->heap_size ] = INT_MAX;

    return minheap_decrease_key(heap, heap->heap_size, value);
}
