# This is the correct way to build a lib

CC=gcc
CFLAGS=-Wall -Winline -O2

OBJS=baz.o extra.o

all: libbaz2.a libbaz2.so

libbaz2.so: libbaz2.so.1.0
	ln -sf $^ $@
libbaz2.so.1.0: libbaz2.so.1.0.3b
	ln -sf $^ $@

libbaz2.so.1.0.3b: $(OBJS:%.o=%.sho)
	$(CC) -o $@ -shared -Wl,-soname,libbaz2.so.1.0 $^ -lc

%.sho: %.c
	$(CC) $(CFLAGS) -D_REENTRANT -fPIC -o $@ -c $<

%.o: %.c
	$(CC) $(CFLAGS) -D_REENTRANT -o $@ -c $<

libbaz2.a: $(OBJS)
	ar cq $@ $(OBJS)
	ranlib $@

clean:
	rm -f *.a *.o *.so* *.sho
