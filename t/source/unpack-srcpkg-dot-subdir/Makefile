name = unpack-srcpkg-dot-subdir

all:
	mkdir -p $(name)
	echo 'Some upstream README' > $(name)/README
	echo '/* some C program */' > $(name)/foo.c
	echo '/* some header */' > $(name)/foo.h
	tar -c -z -f $(name)_1.0.orig.tar.gz ./$(name)
	mkdir -p $(name)/debian
	cp changelog copyright control rules $(name)/debian/
	echo 7 > $(name)/debian/compat
	echo > $(name)/debian/watch
	mkdir $(name)/debian/source
	echo 1.0 > $(name)/debian/source/format
	dpkg-source -sp -b $(name)

clean:
	rm -rf $(name)
	rm -f $(name)_1.0* README foo.c foo.h
