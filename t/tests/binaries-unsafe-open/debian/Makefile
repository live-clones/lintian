all:
	gcc -o dummy dummy.c

install:
	install -d $(DESTDIR)/usr/bin
	install -m 755 -c dummy $(DESTDIR)/usr/bin/'dummy||uname'

clean distclean:
	rm -f dummy

check test:
