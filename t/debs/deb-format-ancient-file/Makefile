all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/deb-format-ancient-file
	cp copyright changelog usr/share/doc/deb-format-ancient-file
	gzip -9 usr/share/doc/deb-format-ancient-file/changelog
	env TZ=GMT touch -t 197001010000 \
	    usr/share/doc/deb-format-ancient-file/changelog.gz
	tar -c -z -f data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	env TZ=GMT touch -t 197001010000 control
	md5sum usr/share/doc/deb-format-ancient-file/* > md5sums
	tar -c -z -f control.tar.gz control md5sums
	ar rc deb-format-ancient-file.deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf usr
