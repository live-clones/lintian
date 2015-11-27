name = control-field-traversal-4

all:
	mkdir -p root/usr/share/doc/
	# create a symlink to (usr/share/doc/)dpkg which will make
	# copyright-file warn that it can't check whether the symlink
	# points to a foreign package if the directory traversal did
	# not happen.
	# If, on the other hand, warns that they don't belong to the
	# same package, there's a directory traversal issue.
	# This is because the 'binary/<pkg>/source' symlink in the
	# laboratory will point to '../../source/../binary/<pkg>'
	# if the bogus source package name is not caught. This results
	# into a valid symlink which is enough for copyright-file to
	# determine that 'source/dpkg' does not exist.
	ln -s dpkg root/usr/share/doc/$(name)

	create-deb -o $(name).deb --root root/ control

clean:
	rm -f *.tar.gz *.deb  debian-binary
	rm -rf root
