Tag: declare-python-versions-for-test
Severity: warning
Check: testsuite
Renamed-from:
 declare-requested-python-versions-for-test
Explanation: The specified test attempts to query the Python versions
 <em>requested</em> by your sources with the command
 <code>py3versions --requested</code> but your sources do not declare
 any versions with the field <code>X-Python3-Version</code>.
 .
 Please choose between two suggested remedies:
 .
 In most circumstances, it is probably best to replace the argument
 <code>--requested</code> with <code>--supported</code>. That will
 exercise the test with all available Python versions.
 .
 Should the test require specific Python versions, please add the field
 <code>X-Python3-Version</code> with the appropriate information to the
 source stanza in the <code>debian/control</code> file.
 .
 No redirection of the output, as in <code>2 &gt; /dev/null</code>, is
 needed in either case.
See-Also:
 py3versions(1),
 Bug#1001677
