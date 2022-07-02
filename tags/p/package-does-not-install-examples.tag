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

Screen: examples/in-tests
Advocates: Scott Kitterman <debian@kitterman.com>
Reason:
 Some sources like python-tomlkit trigger this tag for tests because of files
 in ./tests/examples/. They are not examples for tomlkit, however. They are
 examples of TOML files used in the tests.
 .
 Overall, the check is probably better off not looking in test directories.
See-Also:
 Bug#1005184
