Tag: script-uses-unversioned-python-in-shebang
Severity: error
Check: languages/python/scripts
Explanation: This package contains a script with unversioned Python shebang.
 .
 This package contains a script with unversioned Python shebang and thus
 defaults to using Python 2. The 2.x series of Python is deprecated and apart
 from rare cases, will not be supported in Debian Bullseye.
 .
 If the script in question is compatible with Python 3, please modify it to use
 <code>/usr/bin/python3</code> instead. If it only is Python 2 compatible,
 please modify it to use <code>/usr/bin/python2</code>.
