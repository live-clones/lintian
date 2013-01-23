#define _FILE_OFFSET_BITS 64

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int
zz_open (char *file) {
  return open (file, O_RDONLY);
}
