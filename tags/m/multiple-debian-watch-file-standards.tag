Tag: multiple-debian-watch-file-standards
Severity: warning
Check: debian/watch/standard
Renamed-From:
 debian-watch-file-declares-multiple-versions
Explanation: The <code>debian/watch</code> file in this package contains multiple
 lines starting with <code>version=</code>. There should be only one version
 declaration in a watch file, on the first non-comment line of the file.
See-Also: uscan(1)
