Tag: backgrounded-test-command
Severity: error
Check: testsuite
Explanation:
 This package declares a <code>Test-Command</code> that backgrounds
 itself with an ampersand. That is not a good idea.
 .
 In the <code>autopkgtest</code> framework, the return value determines
 whether a test was successful. It is therefore fundamental to the
 testing process. Unfortunately, that value is being ignored here.
 .
 This test only fails when a message printed to <code>stderr</code>
 wins a race with the <code>autopkgtest</code> harness. While that
 may result in an accurate (but unreliable) detection of some test
 failures, a review of archive-wide <code>autopkgtest</code> data
 shows no failures for backgrounded test commands.
 .
 Many incidents of this tag are based on a faulty command that invokes
 <code>xvfb-run</code> for GUI programs. It was likely adopted from an
 existing package.
 .
 Please drop the ampersand at the end of the <code>Test-Command</code>.
See-Also:
 Bug#988591,
 https://ci.debian.net/doc/
