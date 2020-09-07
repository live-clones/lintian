Tag: mismatched-python-substvar
Severity: warning
Check: languages/python
Explanation: The specified package declares a dependency on <code>${python:Depends}</code>
 whilst appearing to be a Python 3.x package or a dependency on
 <code>${python3:Depends}</code> when it appears to be a package for Python 2.x.
 .
 Please adjust the substvar to match the intended Python version.
