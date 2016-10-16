name = fields-src-fields-filename
dsc  = some-other-name
dir  = $(dsc)-1

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	mkdir $(dir)/debian/source
	echo "1.0" > $(dir)/debian/source/format
	echo $(DEFAULT_DH_COMPAT) > $(dir)/debian/compat
	cp changelog copyright control rules $(dir)/debian/
	tar cfz $(dsc)_1.tar.gz $(dir)
	subst-dsc $(dsc)_1.tar.gz < dsc.in > $(dsc)_1.dsc
	mv $(dsc)_1.dsc $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
	rm -fr $(tar)_1*
