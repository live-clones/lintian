name = files-missing-intermediate-dirs

all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/$(name)
	install -m0644 copyright changelog usr/share/doc/$(name)
	gzip -9 -n usr/share/doc/$(name)/changelog
	tar czf data.tar.gz usr/share/doc/$(name)
	chown 0:0 control
	chmod 644 control
	md5sum usr/share/doc/$(name)/* > md5sums
	tar czf control.tar.gz control md5sums
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb debian-binary
	rm -rf root/
