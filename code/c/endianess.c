#include <stdio.h>

int main()
{
    int i = 1;
    char *b;

    b =  (char *) &i;
    b[0] ? puts("little endian\n") : puts("big endian\n");
}
