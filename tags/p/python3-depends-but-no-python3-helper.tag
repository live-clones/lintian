Tag: python3-depends-but-no-python3-helper
Severity: error
Check: debhelper
Explanation: The source package declares a dependency on ${python3:Depends} in the
 given binary package's debian/control entry. However, debian/rules doesn't
 call any helper that would generate this substitution variable.
