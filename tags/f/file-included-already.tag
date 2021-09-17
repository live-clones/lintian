Tag: file-included-already
Severity: error
Check: debian/copyright/dep5
Explanation: The Debian <code>copyright</code> notes included files with the
 <code>Files-Included</code> field, but the given file would have been shipped
 without it.
 .
 The wildcards in the field may be too broad. Please narrow the criteria for
 files included in the field <code>Files-Included</code>.
See-also:
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
