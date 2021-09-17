Tag: package-does-not-install-examples
Severity: pedantic
Check: examples
Explanation: The original source tarball contains the specified examples
 directory. However, no examples are installed in any binary packages.
 .
 Please use <code>dh&lowbar;installexamples</code> to install these to the most
 relevant package, for example by adding the directory name followed
 by a wildcard to a <code>debian/pkgname.examples</code> file.
 .
 Lintian looks for any directory called <code>examples</code> under
 <code>/usr/share/doc</code> in all binary packages.
See-Also:
 dh_installexamples(1)
