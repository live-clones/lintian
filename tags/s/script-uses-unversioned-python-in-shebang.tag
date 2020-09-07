Tag: script-uses-unversioned-python-in-shebang
Severity: pedantic
Check: languages/python/scripts
Explanation: This package contains a script with unversioned Python shebang.
 .
 The 2.x series of Python is due for deprecation and will not be
 maintained by upstream past 2020. As part of this, there is an on-going
 discussion in Python community to recommend soft-linking python to
 python3 on newer distributions.
 .
 If/when Debian starts following this recommendation, the specified
 script will be broken. However, please do not update this script for
 the time being.
