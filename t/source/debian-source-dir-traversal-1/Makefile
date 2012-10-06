name = debian-source-dir-traversal-1
dir  = $(name)-1

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	# prevent patch-system-but-no-source-readme
	echo "Hallo World" > $(dir)/debian/README.source
	echo 7 > $(dir)/debian/compat
	mkdir $(dir)/debian/source
	echo 1.0 > $(dir)/debian/source/format
	# link to index file for the lab entry
	ln -s ../../index $(dir)/debian/source/git-patches
	mkdir $(dir)/debian/patches
	touch $(dir)/debian/patches/series
	tar cfz $(name)_1.tar.gz $(dir)
	subst-dsc $(name)_1.tar.gz < dsc.in > $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
