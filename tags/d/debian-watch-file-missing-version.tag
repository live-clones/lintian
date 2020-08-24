Tag: debian-watch-file-missing-version
Severity: warning
Check: debian/watch
See-Also: uscan(1)
Explanation: The <tt>debian/watch</tt> file in this package doesn't start a
 <tt>version=</tt> line. The first non-comment line of
 <tt>debian/watch</tt> should be a <tt>version=</tt> declaration. This
 may mean that this is an old version one watch file that should be
 updated to the current version.
