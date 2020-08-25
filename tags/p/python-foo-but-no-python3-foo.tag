Tag: python-foo-but-no-python3-foo
Severity: warning
Check: languages/python
Explanation: This source package appears to generate the specified Python 2 package
 without creating a variant for Python 3.
 .
 The 2.x series of Python is due for deprecation and will not be maintained
 by upstream past 2020 and will likely be dropped after the release of
 Debian "buster".
 .
 If upstream have not moved or have no intention to move to Python 3, please
 be certain that Debian would benefit from the continued inclusion of this
 package and, if not, consider removing it.
 .
 Alternatively, ensure that the corresponding package specifies the
 <code>${python3:Depends}</code> substvar in its binary dependencies.
