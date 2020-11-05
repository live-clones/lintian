Tag: missing-debian-watch-file-standard
Severity: warning
Check: debian/watch/standard
Renamed-From:
 debian-watch-file-missing-version
Explanation: The <code>debian/watch</code> file in this package doesn't start a
 <code>version=</code> line. The first non-comment line of
 <code>debian/watch</code> should be a <code>version=</code> declaration. This
 may mean that this is an old version one watch file that should be
 updated to the current version.
See-Also: uscan(1)
