Tag: usr-share-doc-symlink-without-dependency
Severity: error
Check: debian/copyright
Explanation: If the package installs a symbolic link
 <code>/usr/share/doc/*pkg1* -&gt; *pkg2*</code>, then *pkg1*
 must depend on *pkg2* directory, with the same version as
 *pkg1*.
 .
 Adding the dependency just to fix this bug is often not a good solution.
 Usually, it's better to include a real <code>/usr/share/doc/*pkg1*</code>
 directory within *pkg1* and copy the copyright file into that
 directory.
 .
 Transitive dependencies are not allowed here. In other words, if the
 documentation directory is shipped in *pkg3* and *pkg1* depends
 on *pkg2*, which in turn depends on *pkg3*, that's still an
 error. Copyright file extractors are not required to go more than one
 level deep when resolving dependencies. Each package should have a
 direct dependency on the package which includes its documentation
 directory.
See-Also: policy 12.5
