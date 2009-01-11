all:
	echo '2.0' > debian-binary
	echo 'foo' > extra-stuff
	mkdir -p usr/share/doc/deb-format-extra-member
	cp copyright changelog usr/share/doc/deb-format-extra-member
	gzip -9 usr/share/doc/deb-format-extra-member/changelog
	tar cfz data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/deb-format-extra-member/* > md5sums
	tar cfz control.tar.gz control md5sums
	ar rc deb-format-extra-member.deb \
	    debian-binary control.tar.gz data.tar.gz extra-stuff

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary extra-stuff
	rm -rf usr
