Tag: third-party-package-in-python-dir
Severity: warning
Check: languages/python
Explanation: Third-party Python packages should install their files in
 <code>/usr/lib/python*VERSION*/site-packages</code> for Python versions
 before 2.6 and <code>/usr/lib/python*VERSION*/dist-packages</code>
 for Python 2.6 and later. All other directories in
 <code>/usr/lib/python*VERSION*</code> are for use by the core python
 packages.
See-Also: python-policy 2.5
