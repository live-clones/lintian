CC=gcc
CFLAGS=-Wall -Winline -O2 -fPIC

SONAMES:= libexecbit.so.1
LIBFILES:= $(patsubst %,%.0.1, $(SONAMES))

all: $(LIBFILES)

$(LIBFILES): code.o
	$(CC) -o $@ -shared -Wl,-soname,$(patsubst %.0.1,%,$@) $^ -lc

clean:
	rm -f *.a *.o *.so*

install: all
	install -m 0755 -d $(DESTDIR)/usr/lib
	install -m 0755 *.so* $(DESTDIR)/usr/lib

.PHONY: install clean
