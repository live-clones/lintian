Tag: source-package-encodes-python-version
Severity: warning
Check: languages/python
Explanation: This source package encodes a Python version in its name such
 as <code>python2-foo</code> or <code>python3-bar</code>.
 .
 This could result in a misleading future situation where this source
 package supports multiple versions as well unnecessary given that the
 binary package names will typically encode the supported versions.
 .
 Please override this tag with a suitably-commented override if
 there is no single upstream codebase that supports both versions.
