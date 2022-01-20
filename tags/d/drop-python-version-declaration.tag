Tag: drop-python-version-declaration
Severity: warning
Check: testsuite
Renamed-From:
 query-requested-python-versions-in-test
 query-declared-python-versions-in-test
Explanation:
 Your sources request a specific set of Python versions via the control
 field <code>X-Python3-Version</code> but the named test is ready to work
 with all installed versions.
 .
 You may wish to drop the <code>X-Python3-Version</code> control field
 unless other tests work only with specific Python versions.
 .
 Sources shipping the <code>X-Python3-Version</code> field may not be able
 to remain in Debian <code>testing</code> when Python version 3.9 is
 dropped from there.
 .
 Lintian infers that the specified test is ready because it queries all
 <em>supported</em> Python version with the command
 <code>py3versions --supported</code>.
See-Also:
 py3versions(1),
 Bug#1001677
