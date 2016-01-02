ARCH=$(shell dpkg-architecture -qDEB_HOST_MULTIARCH)
ifeq ($(ARCH), x86_64-linux-gnu)
 ARCH_CROSS=i386-linux-gnu
else
 ARCH_CROSS=x86_64-linux-gnu
endif

all:
	find generated -name '*-config.in' -exec sh -c 'echo "build" {} && cat {} | sed s/\$$\(ARCH\)/$(ARCH)/g | sed s/\$$\(ARCH_CROSS\)/$(ARCH_CROSS)/g > `echo {} | sed s/\-config\.in$$/\-config/g`' \;

install:
	install -d $(DESTDIR)/usr/bin
	install -m 755 generated/*-config $(DESTDIR)/usr/bin

clean distclean:
	rm -f generated/*.config

check test:
