name = control-files-bad

all:
	mkdir -p root/usr/share/doc/$(name)
	install -m0644 copyright changelog root/usr/share/doc/$(name)
	gzip -n -9 root/usr/share/doc/$(name)/changelog

	chown 0:0 control
	chmod 644 control

	cd root && md5sum usr/share/doc/$(name)/* > ../md5sums
	chmod 755 md5sums
	# create a "special control.tar.gz" ; create-deb will
	# use it, instead of creating its own.
	tar czf control.tar.gz --owner=nobody control md5sums

	# --no-fix-perm and --no-md5sums are not strictly needed
	# but the former is to make it explicit and the latter
	# prevents it from re-generating an unused md5sums file
	create-deb -o $(name).deb --no-fix-perm --no-md5sums \
           --root root/

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root/
