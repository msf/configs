#include <stdio.h>
#include "heaps.h"


int main(void)
{
    int arr[] = { 1, 4, 2, 5, 7, 3, 9, -1, -4};

    heap_t *max = maxheap_new( NULL, 9);
    heap_t *min = minheap_new( NULL, 9);

    for(int i= 0; i < 9; i++)
    {
        maxheap_insert(max, arr[i]);
        minheap_insert(min, arr[i]);
    }

    for(int i=0; i < 9; i++) {
        printf("max:%d\tmin:%d\n", maxheap_popmax(max), minheap_popmin(min));
    }

    return 0;
}
