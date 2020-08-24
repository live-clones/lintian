Tag: third-party-package-in-python-dir
Severity: warning
Check: languages/python
Explanation: Third-party Python packages should install their files in
 <tt>/usr/lib/python<i>VERSION</i>/site-packages</tt> for Python versions
 before 2.6 and <tt>/usr/lib/python<i>VERSION</i>/dist-packages</tt>
 for Python 2.6 and later. All other directories in
 <tt>/usr/lib/python<i>VERSION</i></tt> are for use by the core python
 packages.
See-Also: python-policy 2.5
