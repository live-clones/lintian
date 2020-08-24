Tag: source-includes-file-in-files-excluded
Severity: error
Check: debian/copyright/dep5
Explanation: A file specified in the <tt>Files-Excluded</tt> field in
 debian/copyright exists in the source tree.
 .
 This might be a DFSG violation, the referenced files are probably not
 attributed in <tt>debian/copyright</tt>, or the upstream tarball was simply
 not repacked as intended. Alternatively, the field is simply out of date.
 .
 mk-origtargz(1) is typically responsible for removing such files. Support
 in <tt>git-buildpackage</tt> is being tracked in #812721.
