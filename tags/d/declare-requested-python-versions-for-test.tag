Tag: declare-requested-python-versions-for-test
Severity: warning
Check: testsuite
Explanation: The specified test attempts to query the Python versions
 <em>requested</em> by your sources with the command
 <code>py3versions --requested</code> but your sources do not actually
 declare those versions with the field <code>X-Python3-Version</code>.
 .
 Please add the field <code>X-Python3-Version</code> with the appropriate
 information to the source stanza in the <code>debian/control</code> file.
See-Also:
 py3versions(1),
 Bug#1001677
