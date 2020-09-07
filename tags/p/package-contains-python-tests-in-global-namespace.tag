Tag: package-contains-python-tests-in-global-namespace
Severity: warning
Check: files/names
Explanation: This package appears to contain Python test files such as
 <code>test&lowbar;foo.py</code> or <code>test&lowbar;foo/</code> in the global module
 namespace.
 .
 Whilst the tests may be useful in the binary package, it is probably a
 mistake to pollute the "top-level" namespace in this way.
 .
 Please install them to a subdirectory of the module being tested
 instead or simply omit from the binary package entirely.
