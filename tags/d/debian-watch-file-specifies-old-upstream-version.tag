Tag: debian-watch-file-specifies-old-upstream-version
Severity: warning
Check: debian/watch
Explanation: The watch file specifies an upstream version number which matches
 the upstream portion of an old <code>debian/changelog</code> entry, and the
 current <code>debian/changelog</code> entry specifies a newer upstream
 version. The version number in the watch file is very likely to be
 incorrect and probably should be replaced with the current expected
 upstream version. Otherwise, DEHS and similar projects will think the
 package is out of date even when it may not be.
