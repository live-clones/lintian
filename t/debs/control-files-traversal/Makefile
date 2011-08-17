name = control-files-traversal

all:
	echo '2.0' > debian-binary
	install -m 0755 -d usr/share/doc/$(name)
	install -m 0644 changelog copyright usr/share/doc/$(name)
	gzip --best usr/share/doc/$(name)/changelog
	md5sum usr/share/doc/$(name)/* > md5sums
	# Create the traversal symlink - points to md5sums in the lab
	ln -s ../md5sums conffiles
	tar cfz data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	tar cfz control.tar.gz control md5sums
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root/
