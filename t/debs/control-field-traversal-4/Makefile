name = control-field-traversal-4

all:
	echo '2.0' > debian-binary
	mkdir -p usr/share/doc/
	# create a symlink to (usr/share/doc/)dpkg which will make
	# copyright-file warn that it can't check whether the symlink
	# points to a foreign package if the directory traversal did
	# not happen.
	# If, on the other hand, warns that they don't belong to the
	# same package, there's a directory traversal issue.
	# This is because the 'binary/<pkg>/source' symlink in the
	# laboratory will point to '../../source/../binary/<pkg>'
	# if the bogus source package name is not catched. This results
	# into a valid symlink which is enough for copyright-file to
	# determine that 'source/dpkg' does not exist.
	ln -s dpkg usr/share/doc/$(name)
	tar cfz data.tar.gz usr
	chown 0:0 control
	chmod 644 control
	tar cfz control.tar.gz control
	ar rc $(name).deb \
	    debian-binary control.tar.gz data.tar.gz

clean:
	rm -f *.tar.gz *.tar.lzma *.deb md5sums debian-binary
	rm -rf usr
