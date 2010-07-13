#include <stdio.h>

static const char root_dtd_mismatch[]
    = "root and DTD name do not match '%s' and '%s'";

int
main(void)
{
    printf("%s\n", root_dtd_mismatch);
}
