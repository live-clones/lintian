Tag: usr-share-doc-symlink-to-foreign-package
Severity: error
Check: debian/copyright
Explanation: If the package installs a symbolic link
 <code>/usr/share/doc/*pkg1* -&gt; *pkg2*</code>, then *pkg1*
 and *pkg2* must both come from the same source package.
 .
 The best solution is probably to stop symlinking the
 <code>/usr/share/doc</code> directory for this package and instead include a
 real /usr/share/doc/*pkg1* directory within *pkg1* with the
 appropriate contents (such as the <code>copyright</code> and
 <code>changelog.Debian.gz</code> files).
See-Also: policy 12.5
