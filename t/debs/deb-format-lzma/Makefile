name = deb-format-lzma

all:
	mkdir -p root/usr/share/doc/$(name)
	cp copyright changelog root/usr/share/doc/$(name)
	gzip -9 root/usr/share/doc/$(name)/changelog

	create-deb -o $(name).deb --root root -c lzma control

clean:
	rm -f *.tar.gz *.tar.lzma *.deb md5sums debian-binary
	rm -rf root
