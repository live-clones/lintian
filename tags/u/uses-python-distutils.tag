Tag: uses-python-distutils
Severity: info
Check: languages/python/distutils
Explanation: This package uses the Python distutils module.
 .
 In Python 3.10 and 3.11, distutils has been formally marked as deprecated. Code
 that imports distutils will no longer work from Python 3.12.
 .
 Please prepare for this deprecation and migrate away from the Python distutils
 module.
 .
 See-Also: https://peps.python.org/pep-0632
