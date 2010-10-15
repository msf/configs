#include <stdio.h>

const static int digit_base = (int) '0';
const static int digit_top = (int) '9';
int my_atoi(const char *str)
{
    int pos = 0;
    int accum = 0;
    int t, j;
    int start = 0;

    for(pos=0; str[pos] != '\0'; pos++) {
        if( str[pos] >= digit_base && str[pos] <= digit_top)  {
            if(start == 0) start = 1;
            t = (int) str[pos];
            if (start > 0)
                accum = accum * 10 + (t-digit_base);
            else
                accum = accum * 10 - (t-digit_base);
        } else if (start != 0)
            break;
        else if( str[pos] == '-') {
            start = -1;
        }
    }

    return accum;
}



int main(int argc, char *argv[])
{
    char buf[1024];

    do {
        gets(buf);
        printf("my_:%d\n", my_atoi(buf));
        //printf("sys:%d\n", atoi(buf));
    } while( buf[0] != '.');

    return 0;

}
