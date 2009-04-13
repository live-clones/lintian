all:
	gcc -o basic basic.c -pg -Wl,--rpath,/usr/local/lib

install:
	install -d $(DESTDIR)/usr/share/foo/
	install -m 755 -c basic $(DESTDIR)/usr/share/foo/basic
	install -d $(DESTDIR)/usr/lib/debug/usr/share/foo/
	objcopy --only-keep-debug basic $(DESTDIR)/usr/lib/debug/usr/share/foo/basic
	strip -s $(DESTDIR)/usr/lib/debug/usr/share/foo/basic

clean distclean:
	rm -f basic

check test:
