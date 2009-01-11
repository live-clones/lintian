all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/deb-format-wrong-order
	cp copyright changelog usr/share/doc/deb-format-wrong-order
	gzip -9 usr/share/doc/deb-format-wrong-order/changelog
	tar cfz data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/deb-format-wrong-order/* > md5sums
	tar cfz control.tar.gz control md5sums
	ar rc deb-format-wrong-order.deb \
	    debian-binary data.tar.gz control.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf usr
