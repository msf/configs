#include <stdio.h>
#include <unistd.h>


int countcpus()
{
    return sysconf(_SC_NPROCESSORS_CONF);
}

int main()
{
    printf("#cpus: %d\n", countcpus());
    return 0;
}
