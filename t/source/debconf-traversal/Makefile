name = debconf-traversal
dir  = $(name)-1

all:
	mkdir $(dir)
	mkdir $(dir)/debian
	cp changelog copyright control rules $(dir)/debian/
	echo 7 > $(dir)/debian/compat
	mkdir $(dir)/debian/source
	echo 1.0 > $(dir)/debian/source/format
	tar cfz $(name)_1.tar.gz $(dir)
	cp dsc.in $(name)_1.dsc
	perl -I$(LINTIAN_ROOT)/lib -MUtil -i -pe \
	    'BEGIN { $$h = get_file_checksum("sha1", "$(name)_1.tar.gz") } s/\@SHA1\@/$$h/g' $(name)_1.dsc
	perl -I$(LINTIAN_ROOT)/lib -MUtil -i -pe \
	    'BEGIN { $$h = get_file_checksum("sha256", "$(name)_1.tar.gz") } s/\@SHA256\@/$$h/g' $(name)_1.dsc
	perl -I$(LINTIAN_ROOT)/lib -MUtil -i -pe \
	    'BEGIN { $$h = get_file_checksum("md5", "$(name)_1.tar.gz") } s/\@MD5\@/$$h/g' $(name)_1.dsc
	perl -i -pe 'BEGIN { $$s = (stat "$(name)_1.tar.gz")[7] } s/\@SIZE\@/$$s/g' $(name)_1.dsc
	perl -i -pe 's/\@NULL\@/\0/g' $(name)_1.dsc

clean:
	rm -rf $(dir)
	rm -f $(name)_1*
