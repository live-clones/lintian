name = unpack-srcpkg-xz
dir  = $(name)-1.0

all:
	mkdir $(dir)
	echo 'Some upstream README' > $(dir)/README
	tar -c -f $(name)_1.0.orig.tar.xz --xz $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	echo $(DEFAULT_DH_COMPAT) > $(dir)/debian/compat
	touch $(dir)/debian/watch
	mkdir $(dir)/debian/source
	echo '3.0 (quilt)' > $(dir)/debian/source/format
	echo 'Information about patching' > $(dir)/debian/README.source
	dpkg-source -sp -b $(dir)

clean:
	rm -rf $(dir)
	rm -f $(name)_1.0*
