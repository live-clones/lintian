Tag: alternatively-build-depends-on-python-sphinx-and-python3-sphinx
Severity: warning
Check: languages/python
Explanation: This package alternatively Build-Depends on the Python 2 or Python 3
 version of the Sphinx documentation generator.
 .
 The 2.x series of Python is due for deprecation and will not be maintained
 by upstream past 2020 and will likely be dropped after the release of
 Debian "buster".
 .
 Please replace the alternative with a single build dependency on
 <code>python3-sphinx</code>.
