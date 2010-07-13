BINARIES :=  zlib libpng libjpeg libopenjpeg
MANPAGES := $(patsubst %,%.1,$(BINARIES))

all: $(BINARIES) $(MANPAGES)

%: %.c
	gcc -o $* $*.c

%.1: template.1
	sed 's/#BIN#/$*/g' < $< > $@

install:
	install -d $(DESTDIR)/usr/bin
	install -d $(DESTDIR)/usr/share/man/man1
	for b in $(BINARIES); do \
	    install -m 755 -c $$b $(DESTDIR)/usr/bin/$$b; \
	    install -m 644 -c $$b.1 $(DESTDIR)/usr/share/man/man1/$$b.1; \
	done

clean distclean:
	rm -f $(BINARIES) $(MANPAGES)

check test:
