CC=gcc
CFLAGS=-Wall -Winline -O2 -fPIC

SONAME:= libfoo.so.1

all: libfoo.so.1.0.1

libfoo.so.1.0.1: code.o
	$(CC) -o $@ -shared -Wl,-soname,$(SONAME) $^ -lc

clean:
	rm -f *.a *.o *.so* *.sho

install: all
	install -m 0755 -d $(DESTDIR)/usr/lib
	install -m 0644 *.so* $(DESTDIR)/usr/lib
	ln -s libfoo.so.1.0.1 $(DESTDIR)/usr/lib/$(SONAME)

.PHONY: install clean
