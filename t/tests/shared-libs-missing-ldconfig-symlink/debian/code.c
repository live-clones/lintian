#include <stdlib.h>
#include <unistd.h>

void e(void){
  if (fork() != 0)
    exit(1);
}
