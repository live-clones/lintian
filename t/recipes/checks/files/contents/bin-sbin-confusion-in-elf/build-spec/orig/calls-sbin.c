#include <stdio.h>
#include <string.h>

/* may not work as expected on ELF due to ld's SHF_MERGE */
#define BIN_PATH "/bin/our-script"
#define SBIN_PATH "/sbin/our-script"
#define USR_BIN_PATH "/usr/bin/our-script"
#define USR_SBIN_PATH "/usr/sbin/our-script"

int
main(void)
{
    printf("Calling %s\n", BIN_PATH);
    printf("Calling %s\n", SBIN_PATH);
    printf("Calling %s\n", USR_BIN_PATH);
    printf("Calling %s\n", USR_SBIN_PATH);

    return 0;
}
