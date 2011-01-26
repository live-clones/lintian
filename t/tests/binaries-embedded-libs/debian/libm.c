#include <stdio.h>

static const char domain_error[]
    = "neg**non-integral: DOMAIN error";

int
main(void)
{
    printf("%s\n", domain_error);
}
