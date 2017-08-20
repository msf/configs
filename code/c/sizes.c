#include <stdio.h>
#include <time.h>

int main()
{
	float f;
	double d;
	int a;
	long int b;
	short int c;
	void *p;
	time_t t;

	printf("size of (in bytes):\n floats: %02lu\t doubles: %02lu\n long int: %02lu\t int: %02lu\t short int: %02lu\n void* %02lu\ntime_t :%02lu\n",
			sizeof(f),
			sizeof(d),
			sizeof(b),
			sizeof(a),
			sizeof(c),
			sizeof(p),
			sizeof(t)
		  );

	return 0;
}
