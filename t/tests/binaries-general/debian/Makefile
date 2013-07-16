COMPILE:= $(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS)
# extract from readelf
GETBUILDID:=./getbuildid

all:
	# rpath not matching any of the exceptions to the rpath checks
	#  - with profiling enabled.
	$(COMPILE) -o basic basic.c -pg -Wl,--rpath,/usr/local/lib
	# rpath shipped in the package, but one of {/usr}?/lib
	$(COMPILE) -o basiclibrpath basic.c -Wl,--rpath,/usr/lib
	# non-special rpath shipped in the package
	$(COMPILE) -o basicshippedrpath basic.c -Wl,--rpath,/usr/share/foo
	# static version of basic for debugging checks
	$(COMPILE) -static -o basic.static basic.c
	# version with debug
	$(COMPILE) -o basicdebug -g3 -Wl,--build-id basic.c

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
	install -d "$(DESTDIR)/usr/lib/debug/.build-id/"`$(GETBUILDID) -s basicdebug`
	install -m 755 -c basicdebug $(DESTDIR)/usr/share/foo/basicdebug
	# force fake buildid in order to have tag matching ok (deadbeefdeadbeef)
	install -d "$(DESTDIR)/usr/lib/debug/.build-id/de"
	objcopy --compress-debug-sections basicdebug \
		"$(DESTDIR)/usr/lib/debug/.build-id/de/deadbeefdeadbeef.debug"
	install -d "$(DESTDIR)/usr/lib/debug/.build-id/"`$(GETBUILDID) -s basicdebug`
	objcopy --compress-debug-sections --only-keep-debug basicdebug \
		"$(DESTDIR)/usr/lib/debug/.build-id/"`$(GETBUILDID) -s basicdebug`"/"`$(GETBUILDID) -f basicdebug`.debug
	cp basic.static $(DESTDIR)/usr/lib/debug/
	# dh_strip attempts to play the smart guy if the ELF obj is executable.
	cd $(DESTDIR)/usr/lib/debug/ && chmod -x basic basic.static

clean distclean:
	rm -f basic

check test:
