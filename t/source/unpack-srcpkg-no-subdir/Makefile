name = unpack-srcpkg-no-subdir
dir  = $(name)-1.0

all:
	echo 'Some upstream README' > README
	echo '/* some C program */' > foo.c
	echo '/* some header */' > foo.h
	tar -c -z -f $(name)_1.0.orig.tar.gz README foo.c foo.h
	mkdir -p $(dir)/debian
	cp README foo.c foo.h $(dir)
	cp changelog copyright control rules $(dir)/debian/
	cp -R tests/ $(dir)/debian/
	echo $(DEFAULT_DH_COMPAT) > $(dir)/debian/compat
	echo > $(dir)/debian/watch
	mkdir $(dir)/debian/source
	echo 1.0 > $(dir)/debian/source/format
	dpkg-source -sp -b $(dir)

clean:
	rm -rf $(dir)
	rm -f $(name)_1.0* README foo.c foo.h
