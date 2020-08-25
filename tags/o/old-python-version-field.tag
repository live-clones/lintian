Tag: old-python-version-field
Severity: pedantic
Check: languages/python
See-Also: python-policy 3.4
Explanation: The specified Python-Version or Python3-Version field is used to
 specify the version(s) of Python the package supports. However, the
 associated Python version is satisfied by the current "stable"
 distribution of Debian and may be unnecessary.
 .
 Please remove or update the reference. This warning should be ignored
 if you wish to support "sloppy" backports. If removing, please also check
 for the use of <code>py3versions -r</code> in <code>debian/rules</code>, and
 <code>debian/tests/</code>. Without an operative <code>Python3-Version</code>
 field <code>py3versions</code> will fall back to all supported versions
 which may not be appropriate.
