all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/deb-format-lzma
	cp copyright changelog usr/share/doc/deb-format-lzma
	gzip -9 usr/share/doc/deb-format-lzma/changelog
	tar cf data.tar usr
	lzma data.tar
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/deb-format-lzma/* > md5sums
	tar cfz control.tar.gz control md5sums
	ar rc deb-format-lzma.deb \
	    debian-binary control.tar.gz data.tar.lzma

clean:
	rm -f *.tar.gz *.tar.lzma *.deb md5sums debian-binary
	rm -rf usr
