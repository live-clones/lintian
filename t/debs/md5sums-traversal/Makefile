name = md5sums-traversal

all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/$(name)
	cp copyright changelog usr/share/doc/$(name)
	gzip -9 usr/share/doc/$(name)/changelog
	tar czf data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	ln -s ../copyright md5sums
	tar czf control.tar.gz control md5sums
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root/
