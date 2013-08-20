ARCH=$(shell dpkg-architecture -qDEB_HOST_MULTIARCH)

all:
	find generated -name '*.pc.in' -exec sh -c 'echo "build" {} && sed s/\$$\(ARCH\)/$(ARCH)/ {} > `echo {} | sed s/\.pc\.in$$/\.pc/g`' \;

install:
	install -d $(DESTDIR)/usr/lib/pkgconfig/
	install -d $(DESTDIR)/usr/lib/$(ARCH)/pkgconfig/
	install -m 644 indep-*.pc $(DESTDIR)/usr/lib/pkgconfig/
	install -m 644 generated/arch-*.pc $(DESTDIR)/usr/lib/$(ARCH)/pkgconfig/
	install -m 644 generated/indep-*.pc $(DESTDIR)/usr/lib/pkgconfig/

clean distclean:
	rm -f generated/*.pc

check test:
