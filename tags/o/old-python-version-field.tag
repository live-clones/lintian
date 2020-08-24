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
 for the use of <tt>py3versions -r</tt> in <Tt>debian/rules</tt>, and
 <tt>debian/tests/</tt>. Without an operative <tt>Python3-Version</tt>
 field <tt>py3versions</tt> will fall back to all supported versions
 which may not be appropriate.
