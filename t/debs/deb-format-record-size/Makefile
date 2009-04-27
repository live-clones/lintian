all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/deb-format-record-size
	cp copyright changelog usr/share/doc/deb-format-record-size
	gzip -9 usr/share/doc/deb-format-record-size/changelog
	tar --record-size=4096 -c -z -f data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/deb-format-record-size/* > md5sums
	tar --record-size=4096 -c -z -f control.tar.gz control md5sums
	ar rc deb-format-record-size.deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf usr
