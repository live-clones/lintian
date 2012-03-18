#include <stdio.h>

int
lib_interface(int (*a)(char *))
{
    char tmp[10];
    int r = a(tmp);
    if (r < 0) {
      fprintf(stderr, "%s\n", tmp);
    }
    return r;
}
