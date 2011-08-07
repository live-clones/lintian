filename = fields-general-bad
name = $(filename)?

all:
	mkdir -p root/usr/share/doc/$(name)
	cp copyright changelog root/usr/share/doc/$(name)
	gzip -9 root/usr/share/doc/$(name)/changelog

	create-deb -o $(filename).deb --root root control

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root
