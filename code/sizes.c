#include <stdio.h>

int main()
{
	float f;
	double d;
	int a;
	long int b;
	short int c;
	void *p;

	printf("tamanho de:\n floats: %d\t doubles: %d\n long int: %d\t int: %d\t short int: %d\n void* %d\n",
			sizeof(f),
			sizeof(d),
			sizeof(b),
			sizeof(a),
			sizeof(c),
			sizeof(p));

	return 0;
}
