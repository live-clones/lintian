Tag: debian-watch-file-declares-multiple-versions
Severity: warning
Check: debian/watch
See-Also: uscan(1)
Explanation: The <code>debian/watch</code> file in this package contains multiple
 lines starting with <code>version=</code>. There should be only one version
 declaration in a watch file, on the first non-comment line of the file.
