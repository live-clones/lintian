Tag: python-depends-but-no-python-helper
Severity: error
Check: debhelper
Explanation: The source package declares a dependency on ${python:Depends} in the
 given binary package's debian/control entry. However, debian/rules doesn't
 call any helper that would generate this substitution variable.
 .
 The source package probably needs a call to dh_python2 (possibly via the
 python2 dh add-on) in the debian/rules file.
