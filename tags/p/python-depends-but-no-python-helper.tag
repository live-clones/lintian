Tag: python-depends-but-no-python-helper
Severity: error
Check: debhelper
Explanation: The source package declares a dependency on <code>${python:Depends}</code>
 in the given binary package's <code>debian/control</code> entry. However,
 <code>debian/rules</code> doesn't  call any helper that would generate this
 substitution variable.
 .
 The source package probably needs a call to <code>dh&lowbar;python2</code> (possibly via the
 Python2 debhelper add-on) in the <code>debian/rules</code> file.
