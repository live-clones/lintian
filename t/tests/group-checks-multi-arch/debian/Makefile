DATAFILE=data-$(shell dpkg -qDEB_HOST_ARCH)

all:
	echo $(DATAFILE) > $(DATAFILE)

install:
	install -d $(DESTDIR)/usr/lib/pkg-same/
	install -m 0644 $(DATAFILE) $(DESTDIR)/usr/lib/pkg-same/$(DATAFILE)
