Tag: build-depends-on-python-sphinx-only
Severity: warning
Check: languages/python
Explanation: This package Build-Depends on the Python 2.x version of the Sphinx
 documentation generator.
 .
 The 2.x series of Python is due for deprecation and will not be maintained
 by upstream past 2020 and will likely be dropped after the release of
 Debian "buster".
 .
 Some Python modules may need to depend on both <code>python-sphinx</code> and
 <code>python3-sphinx</code> but please consider moving to only Build-Depending on
 the <code>python3-sphinx</code> package instead.
