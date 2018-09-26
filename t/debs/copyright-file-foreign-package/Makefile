name = copyright-file-foreign-package

all:
	-mkdir -p root/usr/share/doc/
	ln -sf other-package root/usr/share/doc/$(name)

	create-deb -o $(name).deb --no-md5sums --root root/ control

clean:
	rm -f *.tar.gz *.deb debian-binary
	rm -rf root/
