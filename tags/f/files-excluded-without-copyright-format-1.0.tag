Tag: files-excluded-without-copyright-format-1.0
Severity: error
Check: debian/copyright/dep5
Explanation: The <code>Files-Excluded</code> field in <code>debian/copyright</code> is
 used to exclude files from upstream source packages such as when they
 violate the Debian Free Software Guidelines
 .
 However, this field will be ignored by uscan(1) if the <code>copyright</code>
 file is not declared as following the <code>1.0</code> format.
 .
 Please ensure your <code>debian/copyright</code> file starts with the
 following line:
 .
   Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
See-Also: uscan(1)
