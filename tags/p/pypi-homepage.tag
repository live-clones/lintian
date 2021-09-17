Tag: pypi-homepage
Severity: warning
Check: languages/python/homepage
Explanation: The <code>Homepage</code> field in this package's
 control file refers to the Python Package Index (PyPI), and
 not to the true upstream.
 .
 Debian packages should point at the upstream's homepage, but
 PyPI is just another packaging system. You may be able to
 find the correct information in the <code>Homepage</code> link
 on the corresponding PyPI web page (under the "Project details"
 tab).
See-Also:
 Bug#981932
