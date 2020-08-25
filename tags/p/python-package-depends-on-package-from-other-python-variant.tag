Tag: python-package-depends-on-package-from-other-python-variant
Severity: warning
Check: languages/python
Explanation: Either the specified Python 3.x package declares a dependency on a
 Python 2.x package, or the specified Python 2.x package depends on a Python
 3.x package.
 .
 This is likely a typo in <code>debian/control</code> or due to misconfigured
 calls to, for example, <code>dh&lowbar;installdocs --link-doc=PKG</code>.
See-Also: Bug#884692
