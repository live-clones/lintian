name = changelog-file-syntax

all:

	mkdir -p root/usr/share/doc/$(name)
	install -m0644 copyright changelog root/usr/share/doc/$(name)
	gzip -9n root/usr/share/doc/$(name)/changelog
	create-deb --root root/ -o $(name).deb control

clean:
	rm -f *.tar.gz *.deb debian-binary md5sums
	rm -rf root/
