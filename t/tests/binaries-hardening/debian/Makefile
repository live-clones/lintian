all: weak.1 strong.1
	# Build without dpkg-buildflags.
	gcc -o weak -g \
		-fno-stack-protector \
		-Wl,-z,norelro \
		-U_FORTIFY_SOURCE \
		hello.c
	gcc -o strong \
		$(shell dpkg-buildflags --get CPPFLAGS) \
		$(shell dpkg-buildflags --get CFLAGS) \
		$(shell dpkg-buildflags --get LDFLAGS) \
		hello.c
%.1: base.pod
	sed s/@NAME@/$(basename $@)/g < $< | \
	   pod2man --name $(basename $@) --section 1 > $@

install:
	install -d $(DESTDIR)/usr/bin/
	install -d $(DESTDIR)/usr/share/man/man1
	install -m 755 -c weak $(DESTDIR)/usr/bin/weak
	install -m 755 -c strong $(DESTDIR)/usr/bin/strong
	install -m 644 -c weak.1 $(DESTDIR)/usr/share/man/man1/weak.1
	install -m 644 -c strong.1 $(DESTDIR)/usr/share/man/man1/strong.1

clean distclean:
	rm -f weak strong *.1

check test:
