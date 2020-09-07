Tag: cannot-check-whether-usr-share-doc-symlink-points-to-foreign-package
Severity: info
Check: debian/copyright
Explanation: There is a symlink /usr/share/doc/*pkg1* -&gt; *pkg2*
 in your package. This means that *pkg1* and *pkg2* must
 both come from the same source package. Lintian cannot check this right now
 however.
 .
 Please reprocess this binary together with its source package to avoid
 this tag.
