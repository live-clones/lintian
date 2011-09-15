name = control-files-traversal

all:
	ln -s ../md5sums conffiles
	create-deb -o $(name).deb conffiles control

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root/
