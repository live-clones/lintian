CC=gcc
CFLAGS+= -fPIC

SONAME:= libfoo-1.so
DEVSYMLINK:=$(shell echo $(SONAME) | perl -pe 's:-[\d\.]*\.so$$:\.so:')
LIBFILES:=$(SONAME)

all: $(LIBFILES)

$(LIBFILES): code.o
	$(CC) $(LDFLAGS) -o $@ -shared -Wl,-soname,$@ $^ -lc

clean:
	rm -f *.a *.o *.so*

install: all
	echo $(SONAME) -- $(DEVSYMLINK)
	install -m 0755 -d $(DESTDIR)/usr/lib
	install -m 0755 -d $(DESTDIR)/usr/include
	install -m 0644 $(SONAME) $(DESTDIR)/usr/lib
	ln -s $(SONAME) $(DESTDIR)/usr/lib/$(DEVSYMLINK)
	install -m 0644 code.h $(DESTDIR)/usr/include

.PHONY: install clean
