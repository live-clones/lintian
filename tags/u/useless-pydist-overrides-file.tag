Tag: useless-pydist-overrides-file
Severity: info
Check: languages/python/dist-overrides
Explanation: The package has a pydist-overrides file which
 was used for Python2 overrides and is now obsolete.
 .
 If overrides for Python3 packages are needed, they should be
 present in the <code>debian/py3dist-overrides</code> file.
