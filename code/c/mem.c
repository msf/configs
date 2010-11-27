#include <stdio.h>
#include <stdlib.h>

char bss;
char data = 'a';

 int test(void)
 {
	 char a;
	 char *s;
	 s = (char *) malloc(sizeof(char));
	 printf("heap: %p\tstack: %p\tdata: %p\tbss: %p\n", s,&a, &data, &bss);
	 free(s);
	 return 0;
 }

int main(void)
{
	test();
	return 0;
}
