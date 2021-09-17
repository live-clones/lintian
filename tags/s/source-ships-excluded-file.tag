Tag: source-ships-excluded-file
Severity: error
Check: debian/copyright/dep5
Renamed-From:
 source-includes-file-in-files-excluded
Explanation: A file specified in the <code>Files-Excluded</code> field in
 debian/copyright exists in the source tree.
 .
 This might be a DFSG violation, the referenced files are probably not
 attributed in <code>debian/copyright</code>, or the upstream tarball was simply
 not repacked as intended. Alternatively, the field is simply out of date.
 .
 mk-origtargz(1) is typically responsible for removing such files. Support
 in <code>git-buildpackage</code> is being tracked in Bug#812721.
