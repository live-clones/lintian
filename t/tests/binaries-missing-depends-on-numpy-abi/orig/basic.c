#include <Python.h>
#include <numpy/arrayobject.h>
#include <stdio.h>
#include <string.h>

static void
hardening_trigger(char *p, int i, void (*f)(char *))
{
    char test[10];
    memcpy(test, p, i);
    f(test);
    printf("%s", test);
}

void do_import_array(void)
{
    import_array();
    hardening_trigger(NULL, 0, NULL);
}
