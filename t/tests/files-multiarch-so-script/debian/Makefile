
# Since dpkg in stable (Squeeze) does not support MULTIARCH we cannot use
#  dpkg-architecture -qDEB_HOST_MULTIARCH
# Therefore this test is hardcoded to x86 and amd64

ARCH=$(shell dpkg-architecture -qDEB_HOST_ARCH)

ifeq (i386,$(ARCH))
    TRIPLETT = i386-linux-gnu
else
    TRIPLETT = x86_64-linux-gnu
endif


all:
	echo "INPUT(libsome.so)" > libbasic.so.2

install:
	# install it under the correct triplet directory
	install -d $(DESTDIR)/usr/lib/$(TRIPLETT)
	install -m 644 -c libbasic.so.2 $(DESTDIR)/usr/lib/$(TRIPLETT)/libbasic.so.2

clean distclean:
	rm -f libbasic.so.2

check test:
