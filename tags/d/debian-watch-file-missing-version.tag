Tag: debian-watch-file-missing-version
Severity: warning
Check: debian/watch
See-Also: uscan(1)
Explanation: The <code>debian/watch</code> file in this package doesn't start a
 <code>version=</code> line. The first non-comment line of
 <code>debian/watch</code> should be a <code>version=</code> declaration. This
 may mean that this is an old version one watch file that should be
 updated to the current version.
