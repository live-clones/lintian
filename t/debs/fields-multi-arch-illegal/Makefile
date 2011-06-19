all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/fields-multi-arch-illegal
	cp copyright changelog usr/share/doc/fields-multi-arch-illegal
	gzip -9 usr/share/doc/fields-multi-arch-illegal/changelog
	tar czf data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/fields-multi-arch-illegal/* > md5sums
	tar cfz control.tar.gz control md5sums
	ar rc fields-multi-arch-illegal.deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.tar.lzma *.deb md5sums debian-binary
	rm -rf usr
