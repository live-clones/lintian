Tag: debian-watch-file-specifies-wrong-upstream-version
Severity: warning
Check: debian/watch
See-Also: uscan(1)
Explanation: The watch file specifies an upstream version which exactly matches
 the version of a <code>debian/changelog</code> entry, this is not a
 native package, and no version mangling is being done. The version
 field in a watch file should specify the expected upstream version, not
 the version of the Debian package. Any epochs and Debian revisions
 should be removed first or mangled away.
