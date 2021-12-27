Tag: runtime-test-file-build-depends-python-all-without-using-all-supported-python-versions
Severity: warning
Check: testsuite
Explanation: The specified file appears to use <code>python3-all</code> (or
 equivalent) as a build-dependency without using <code>py3versions -s</code> to
 determine the "supported" Python versions.
 .
 By using only the default version of Python installed, the autopkgtest may
 pass now, but the package might fail in the future using another, non-default,
 Python version.
 .
 Please modify the autopkgtest so that the test runs for each of the available
 Python versions.
