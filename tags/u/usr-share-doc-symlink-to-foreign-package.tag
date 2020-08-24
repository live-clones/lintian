Tag: usr-share-doc-symlink-to-foreign-package
Severity: error
Check: debian/copyright
Explanation: If the package installs a symbolic link
 <tt>/usr/share/doc/<i>pkg1</i> -&gt; <i>pkg2</i></tt>, then <i>pkg1</i>
 and <i>pkg2</i> must both come from the same source package.
 .
 The best solution is probably to stop symlinking the
 <tt>/usr/share/doc</tt> directory for this package and instead include a
 real /usr/share/doc/<i>pkg1</i> directory within <i>pkg1</i> with the
 appropriate contents (such as the <tt>copyright</tt> and
 <tt>changelog.Debian.gz</tt> files).
See-Also: policy 12.5
