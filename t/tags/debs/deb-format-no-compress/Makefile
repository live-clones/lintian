name = deb-format-no-compress

# Done by hand, create-deb cannot do this and it would
# be "too much effort" to make it be able to do it.
all:
	create-deb -o $(name).deb --control-compression none \
	  -c none control
clean:
	rm -f *.tar *.deb md5sums debian-binary
	rm -rf root
