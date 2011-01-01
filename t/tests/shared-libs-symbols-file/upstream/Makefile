CC=gcc
CFLAGS=-Wall -Winline -O2 -fPIC

FOO_SONAME:= libfoo.so.1
SYM_SONAME:= libsym.so.1

all: libfoo.so.1.0.1 libsym.so.1.0.1

libfoo.so.1.0.1: code.o
	$(CC) -o $@ -shared -Wl,-soname,$(FOO_SONAME) $^ -lc

libsym.so.1.0.1: code.o
	$(CC) -o $@ -shared -Wl,-soname,$(SYM_SONAME) $^ -lc

clean:
	rm -f *.a *.o *.so*

install: all
	install -m 0755 -d $(DESTDIR)/usr/lib
	install -m 0644 *.so* $(DESTDIR)/usr/lib
	ln -s libfoo.so.1.0.1 $(DESTDIR)/usr/lib/$(FOO_SONAME)
	ln -s libsym.so.1.0.1 $(DESTDIR)/usr/lib/$(SYM_SONAME)

.PHONY: install clean
