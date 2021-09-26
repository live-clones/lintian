Tag: runtime-test-file-uses-supported-python-versions-without-test-depends
Severity: warning
Check: testsuite
Renamed-From:
 runtime-test-file-uses-supported-python-versions-without-python-all-build-depends
Explanation: The specified file appears to use <code>py3versions -s</code> to
 determine the "supported" Python versions without specifying
 <code>python3-all</code> (or equivalent) as a test prerequisite.
 .
 With only the default version of Python installed, the autopkgtests may
 pass but the package subsequently fails at runtime when another,
 non-default, Python version is present.
 .
 Please add <code>python3-all</code> as a test prerequisite via <code>Depends</code>
 in <code>debian/tests/control</code>.
