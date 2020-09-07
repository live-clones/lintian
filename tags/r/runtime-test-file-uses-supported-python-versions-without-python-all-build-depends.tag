Tag: runtime-test-file-uses-supported-python-versions-without-python-all-build-depends
Severity: warning
Check: testsuite
Explanation: The specified file appears to use <code>py3versions -s</code> to
 determine the "supported" Python versions without specifying
 <code>python3-all</code> (or equivalent) as a build-dependency.
 .
 With only the default version of Python installed, the autopkgtests may
 pass but the package subsequently faisl at runtime when another,
 non-default, Python version is present.
 .
 Please add <code>python3-all</code> as a build-dependency.
