name = deb-format-record-size

# Build the deb manully, since we need to fiddle with
# with the record-size.
all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/$(name)
	cp copyright changelog usr/share/doc/$(name)
	gzip -9 usr/share/doc/$(name)/changelog
	tar --record-size=4096 -c -z -f data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/$(name)/* > md5sums
	tar --record-size=4096 -c -z -f control.tar.gz control md5sums
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf usr
