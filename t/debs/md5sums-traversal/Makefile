name = md5sums-traversal

all:
	ln -sf ../copyright md5sums
	create-deb -o $(name).deb control md5sums

clean:
	rm -f *.tar.gz *.deb md5sums debian-binary
	rm -rf root/
