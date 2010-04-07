BINARIES :=  zlib libpng

all: $(BINARIES)

%: %.c
	gcc -o $* $*.c

install:
	install -d $(DESTDIR)/usr/bin
	for b in $(BINARIES); do \
	    install -m 755 -c $$b $(DESTDIR)/usr/bin/$$b; \
	done

clean distclean:
	rm -f $(BINARIES)

check test:
