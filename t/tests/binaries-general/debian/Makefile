all:
	# rpath not matching any of the exceptions to the rpath checks
	#  - with profiling enabled.
	gcc -o basic basic.c -pg -Wl,--rpath,/usr/local/lib
	# rpath shipped in the package, but one of {/usr}?/lib
	gcc -o basiclibrpath basic.c -Wl,--rpath,/usr/lib
	# non-special rpath shipped in the package
	gcc -o basicshippedrpath basic.c -Wl,--rpath,/usr/share/foo
	# static version of basic for debugging checks
	gcc -static -o basic.static basic.c

install:
	install -d $(DESTDIR)/usr/share/foo/
	install -m 755 -c basic $(DESTDIR)/usr/share/foo/basic
	install -d $(DESTDIR)/usr/lib/debug/usr/share/foo/
	objcopy --only-keep-debug basic $(DESTDIR)/usr/lib/debug/usr/share/foo/basic
	strip -s $(DESTDIR)/usr/lib/debug/usr/share/foo/basic
	install -d $(DESTDIR)/usr/lib/foo/
	install -m 755 -c basiclibrpath $(DESTDIR)/usr/lib/foo/basiclibrpath
	install -m 755 -c basicshippedrpath $(DESTDIR)/usr/lib/foo/basicshippedrpath
	objcopy --only-keep-debug basic $(DESTDIR)/usr/lib/debug/basic
	cp basic.static $(DESTDIR)/usr/lib/debug/
	# dh_strip attempts to play the smart guy if the ELF obj is executable.
	cd $(DESTDIR)/usr/lib/debug/ && chmod -x basic basic.static

clean distclean:
	rm -f basic

check test:
