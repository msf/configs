#include <stdio.h>

/*
 * If we list all the natural numbers below 10 that are multiples of 3 or 5, we get 3, 5, 6 and 9. The sum of these multiples is 23.
 *
 * Find the sum of all the multiples of 3 or 5 below 1000.
 */
int solve_p1()
{

    int start = 0;
    int end = 1000;
    int i;
    unsigned accum = 0;

    for (i = start; i < end; i++) {

        if( i%3==0 || i%5 == 0)
            accum +=i;
    }
    return accum;
}

int

long solve_p5()
{
    long i,j,k;

    long start = 1*2*3*5*7*11*13*17;
    long stop;

    for(i=1; i <21; i++)
        stop *= i;

    for(i= start; i<stop; i++) {

        if( i%2==0 &&
            i%3==0 &&
            i%4==0 &&
            i%5==0 &&
            i%6==0 &&
            i%7==0 &&
            i%8==0 &&
            i%9==0 &&
            i%10==0 &&
            i%11==0 &&
            i%12==0 &&
            i%13==0 &&
            i%14==0 &&
            i%15==0 &&
            i%16==0 &&
            i%17==0 &&
            i%18==0 &&
            i%19==0 &&
            i%20==0 )
            return i;
    }
    return i;
}

long solve_p6()
{
    long t1 = 0;
    long t2 = 0;
    long j,k,i;

    for(i = 0; i <= 100; i++){
        t1 += i*i;
        t2 += i;
    }
    t2 = t2*t2;
    return t2-t1;
}

long solve_p20()
{
    char *soma= "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000";

    long i=0;
    for(; soma[i] != '\0'; i++) {
        i += (int) soma[i] - (int) '0';
    }
    return i;
}

void main()
{
    printf("%d\n", solve_p1());
    printf("%ld\n", solve_p6());
    printf("%ld\n", solve_p20());
}


