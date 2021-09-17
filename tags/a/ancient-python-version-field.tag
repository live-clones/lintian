Tag: ancient-python-version-field
Severity: warning
Check: languages/python
See-Also: python-policy 3.4
Explanation: The control fields <code>Python-Version</code> and
 <code>Python3-Version</code> show the Python versions your package
 supports, but the Python version listed here predates the current
 "oldstable" distribution. There is no need to list it.
 .
 Please drop or update the named version.
 .
 When removing a version, please check <code>debian/rules</code> and
 <code>debian/tests/&ast;</code> for any use of <code>py3versions -r</code>.
 Without a <code>Python3-Version</code> field, that program falls back to
 all supported versions, which may not be what you want.
