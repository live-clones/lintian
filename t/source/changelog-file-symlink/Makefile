name = changelog-file-symlink
dir  = $(name)-1

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	mv $(dir)/debian/changelog $(dir)/debian/changelog.old
	ln -s changelog.old $(dir)/debian/changelog
	echo 7 > $(dir)/debian/compat
	mkdir $(dir)/debian/source
	echo '3.0 (quilt)' > $(dir)/debian/source/format
	tar cfz $(name)_1.tar.gz $(dir)
	subst-dsc $(name)_1.tar.gz < dsc.in > $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
