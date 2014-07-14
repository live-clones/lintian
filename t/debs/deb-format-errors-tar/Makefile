name = deb-format-errors-tar

all:
	mkdir -p usr/share/doc/$(name)
	install -m0644 copyright changelog usr/share/doc/$(name)
	gzip -9 -n usr/share/doc/$(name)/changelog

	tar --xform 's,^,/,' -czf data.tar.gz usr/

	md5sum usr/share/doc/$(name)/* > md5sums

	chmod 644 control md5sums
	chown 0:0 control md5sums

	echo '2.0' > debian-binary
	tar czf control.tar.gz control md5sums
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary

