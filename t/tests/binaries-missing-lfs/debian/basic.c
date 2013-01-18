#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>


static void
hardening_trigger(char *p, int i, void (*f)(char *))
{
    char test[10];
    memcpy(test, p, i);
    f(test);
    printf("%s", test);
}

int
lib_interface(void)
{
    printf("Hello world!\n");
    hardening_trigger(NULL, 0, NULL);
}

int
do_open (char *file) {
  return open (file, O_RDONLY);
}
