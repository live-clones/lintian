#include <stdio.h>
#include <string.h>

int
main(int argc, char *argv[])
{
    char t[10];
    printf("Hello world!\n");
    /* Bad choice for reading from a security point of view, but it forces a stack
       protector, so meh.
     */
    if(argc > 0)
       (void) strcpy(t,argv[0]);
}
