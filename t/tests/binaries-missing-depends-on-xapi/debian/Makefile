all:
	gcc -fPIC -shared -Wl,-z,defs -Wl,-soname,libbasic.so.2 -o libbasic.so basic.c

install:
	# install it under the correct triplet directory
	install -d $(DESTDIR)/usr/lib/perl5
	install -m 644 -c -s libbasic.so $(DESTDIR)/usr/lib/perl5/libbasic.so
	install -d $(DESTDIR)/usr/lib/php5
	install -m 644 -c -s libbasic.so $(DESTDIR)/usr/lib/php5/libbasic.so

clean distclean:
	rm -f libbasic.so.2

check test:
