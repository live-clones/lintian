Tag: query-requested-python-versions-in-test
Severity: warning
Check: testsuite
Explanation: The specified test queries all <em>supported</em> Python versions
 with the command <code>py3versions --supported</code> but your sources request
 a specific set of versions via the field <code>X-Python3-Version</code>.
 .
 Please query only the requested versions with the command
 <code>py3versions --requested</code>.
See-Also:
 py3versions(1),
 Bug#1001677
