name = control-files-weird-files

all:
	mkdir -p root/usr/share/doc/$(name)
	cp copyright changelog root/usr/share/doc/$(name)
	gzip -9 root/usr/share/doc/$(name)/changelog

	touch triggers
	create-deb -o $(name).deb --root root/ control triggers \
		special-file isinstallable

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary triggers
	rm -rf root/
