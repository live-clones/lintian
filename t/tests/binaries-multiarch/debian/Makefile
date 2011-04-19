
TRIPLETT = $(shell dpkg-architecture -qDEB_HOST_MULTIARCH)

ifeq (i386-linux-gnu,$(TRIPLETT))
    WRONG_TRIPLETT = x86_64-linux-gnu
else
    WRONG_TRIPLETT = i386-linux-gnu
endif

all:
	gcc -o basic basic.c

install:
	# install it once under the correct triplet directory
	install -d $(DESTDIR)/usr/lib/$(TRIPLETT)
	install -m 755 -c basic $(DESTDIR)/usr/lib/$(TRIPLETT)/basic
	# and one more time under the wrong triplet directory
	install -d $(DESTDIR)/usr/lib/$(WRONG_TRIPLETT)
	install -m 755 -c basic $(DESTDIR)/usr/lib/$(WRONG_TRIPLETT)/basic

clean distclean:
	rm -f basic

check test:
