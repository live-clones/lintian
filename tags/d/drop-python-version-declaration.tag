Tag: drop-python-version-declaration
Severity: warning
Check: testsuite
Renamed-From:
 query-requested-python-versions-in-test
 query-declared-python-versions-in-test
Explanation:
 Your sources request a specific set of Python versions via the control field
 <code>X-Python3-Version</code> but all declared autopkgtests exercise all supported
 Python versions by using the command <code>py3versions --supported</code>.
 .
 The <code>X-Python3-Version</code> control field is not needed when sources work
 with all Python versions currently supported.
See-Also:
 py3versions(1),
 Bug#1001677
