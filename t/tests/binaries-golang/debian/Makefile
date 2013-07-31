COMPILE:= $(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS)

all:
	# static version
	$(COMPILE) -static -o basic.static basic.c

install:
	install -d $(DESTDIR)/usr/lib/foo/
	install -m 755 basic.static $(DESTDIR)/usr/lib/foo/static

clean distclean:
	rm -f basic

check test:
