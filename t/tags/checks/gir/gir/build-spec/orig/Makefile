multiarch := $(shell dpkg-architecture -qDEB_HOST_ARCH)

all:
	install -d usr/lib/$(multiarch)/girepository-1.0
	cp usr/lib/libgood-42-dev-dummy usr/lib/$(multiarch)/libperfect-42-dev-dummy
	cp usr/lib/libgood-42-0-dummy usr/lib/$(multiarch)/libperfect-42-0-dummy
	cp usr/lib/girepository-1.0/Good-42.typelib usr/lib/$(multiarch)/girepository-1.0/Perfect-42.typelib
