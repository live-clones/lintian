all:
	# rpath not matching any of the exceptions to the rpath checks
	gcc -o basic basic.c -pg -Wl,--rpath,/usr/local/lib
	# rpath shipped in the package, but one of {/usr}?/lib
	gcc -o basiclibrpath basic.c -ph -Wl,--rpath,/usr/lib
	# non-special rpath shipped in the package
	gcc -o basicshippedrpath basic.c -ph -Wl,--rpath,/usr/share/foo

install:
	install -d $(DESTDIR)/usr/share/foo/
	install -m 755 -c basic $(DESTDIR)/usr/share/foo/basic
	install -d $(DESTDIR)/usr/lib/debug/usr/share/foo/
	objcopy --only-keep-debug basic $(DESTDIR)/usr/lib/debug/usr/share/foo/basic
	strip -s $(DESTDIR)/usr/lib/debug/usr/share/foo/basic
	install -d $(DESTDIR)/usr/lib/foo/
	install -m 755 -c basiclibrpath $(DESTDIR)/usr/lib/foo/basiclibrpath
	install -m 755 -c basicshippedrpath $(DESTDIR)/usr/lib/foo/basicshippedrpath

clean distclean:
	rm -f basic

check test:
