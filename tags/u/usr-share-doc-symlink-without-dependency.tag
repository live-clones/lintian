Tag: usr-share-doc-symlink-without-dependency
Severity: error
Check: debian/copyright
Explanation: If the package installs a symbolic link
 <code>/usr/share/doc/<i>pkg1</i> -&gt; <i>pkg2</i></code>, then <i>pkg1</i>
 must depend on <i>pkg2</i> directory, with the same version as
 <i>pkg1</i>.
 .
 Adding the dependency just to fix this bug is often not a good solution.
 Usually, it's better to include a real <code>/usr/share/doc/<i>pkg1</i></code>
 directory within <i>pkg1</i> and copy the copyright file into that
 directory.
 .
 Transitive dependencies are not allowed here. In other words, if the
 documentation directory is shipped in <i>pkg3</i> and <i>pkg1</i> depends
 on <i>pkg2</i>, which in turn depends on <i>pkg3</i>, that's still an
 error. Copyright file extractors are not required to go more than one
 level deep when resolving dependencies. Each package should have a
 direct dependency on the package which includes its documentation
 directory.
See-Also: policy 12.5
