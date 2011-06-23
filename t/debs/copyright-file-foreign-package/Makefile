name = copyright-file-foreign-package

all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/
	ln -s other-package usr/share/doc/$(name)
	tar cfz data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	tar cfz control.tar.gz control
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.tar.lzma *.deb md5sums debian-binary
	rm -rf usr
