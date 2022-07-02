Tag: test-leaves-python-version-untested
Severity: warning
Check: testsuite
Explanation: The named autopkgtest declares <code>python3-all</code> or an equivalent
 as a runtime prerequisite but the test script does not query the supported Python
 versions with <code>py3versions --supported</code>.
 .
 The test may pass with the standard Python version but could fail in the future with
 a Python version that is already available now.
 .
 It is best to run tests for all Python versions supported by the target system.
