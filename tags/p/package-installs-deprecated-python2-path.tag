Tag: package-installs-deprecated-python2-path
Severity: error
Check: languages/python
Explanation:
 The package is installing files into the <code>/usr/lib/python2*</code>
 directory, which deprecated since the Python 2 EOL.
 .
 Python 2 is not supported anymore and such files should not be installed by a
 package.
