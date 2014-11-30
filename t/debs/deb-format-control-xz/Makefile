name = deb-format-control-xz

# Done by hand, create-deb cannot do this and it would
# be "too much effort" to make it be able to do it.
all:
	create-deb -o $(name).deb --control-compression xz -c xz \
	    control
clean:
	rm -f *.tar.xz *.deb md5sums debian-binary
	rm -rf root
