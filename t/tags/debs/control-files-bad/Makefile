name = control-files-bad

all:
	-mkdir -p root/usr/share/doc/$(name)
	install -m0644 copyright changelog root/usr/share/doc/$(name)
	gzip -n -9 -f root/usr/share/doc/$(name)/changelog

	chown 0:0 control
	chmod 644 control

	cd root && md5sum usr/share/doc/$(name)/* > ../md5sums
	chmod 755 md5sums
	# create a "special control.tar.gz"
	tar czf control.tar.gz --owner=nobody control md5sums

	# cannot use create-deb; create deb manually
	tar -cf ./data.tar.gz -C root/ .
	echo 2.0 > debian-binary
	ar rc $(name).deb debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root/
