name = fields-src-fields-filename
dsc  = some-other-name
dir  = $(dsc)-1

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	mkdir $(dir)/debian/source
	echo "1.0" > $(dir)/debian/source/format
	echo 7 > $(dir)/debian/compat
	cp changelog copyright control rules $(dir)/debian/
	tar cfz $(dsc)_1.tar.gz $(dir)
	cp dsc.in $(dsc)_1.dsc
	perl -I$(LINTIAN_ROOT)/lib -MLintian::Util -i -pe \
	    'BEGIN { $$h = get_file_checksum("sha1", "$(dsc)_1.tar.gz") } s/\@SHA1\@/$$h/g' $(dsc)_1.dsc
	perl -I$(LINTIAN_ROOT)/lib -MLintian::Util -i -pe \
	    'BEGIN { $$h = get_file_checksum("sha256", "$(dsc)_1.tar.gz") } s/\@SHA256\@/$$h/g' $(dsc)_1.dsc
	perl -I$(LINTIAN_ROOT)/lib -MLintian::Util -i -pe \
	    'BEGIN { $$h = get_file_checksum("md5", "$(dsc)_1.tar.gz") } s/\@MD5\@/$$h/g' $(dsc)_1.dsc
	perl -i -pe 'BEGIN { $$s = (stat "$(dsc)_1.tar.gz")[7] } s/\@SIZE\@/$$s/g' $(dsc)_1.dsc
	mv $(dsc)_1.dsc $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
	rm -fr $(tar)_1*
