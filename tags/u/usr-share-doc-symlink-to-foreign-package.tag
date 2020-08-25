Tag: usr-share-doc-symlink-to-foreign-package
Severity: error
Check: debian/copyright
Explanation: If the package installs a symbolic link
 <code>/usr/share/doc/<i>pkg1</i> -&gt; <i>pkg2</i></code>, then <i>pkg1</i>
 and <i>pkg2</i> must both come from the same source package.
 .
 The best solution is probably to stop symlinking the
 <code>/usr/share/doc</code> directory for this package and instead include a
 real /usr/share/doc/<i>pkg1</i> directory within <i>pkg1</i> with the
 appropriate contents (such as the <code>copyright</code> and
 <code>changelog.Debian.gz</code> files).
See-Also: policy 12.5
