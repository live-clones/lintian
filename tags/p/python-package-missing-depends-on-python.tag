Tag: python-package-missing-depends-on-python
Severity: error
Check: languages/python
Explanation: The specified Python package ships Python modules under
 <code>/usr/lib</code> but does not specify any dependency on Python.
 .
 This is likely an omission, the result of a typo in
 <code>debian/control</code> or the file should not be installed.
