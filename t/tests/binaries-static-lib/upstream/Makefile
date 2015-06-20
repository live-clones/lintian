CC=gcc
CFLAGS+= -g
LIBFILES:= libfoo.a

all: $(LIBFILES)

$(LIBFILES): code.o other.o
	ar rcs -o $@ $^

clean:
	rm -f *.a *.o

install: all
	install -m 0755 -d $(DESTDIR)/usr/lib
	install -m 0755 -d $(DESTDIR)/usr/include
	install -m 0644 *.a $(DESTDIR)/usr/lib
	install -m 0644 code.h $(DESTDIR)/usr/include

.PHONY: install clean
