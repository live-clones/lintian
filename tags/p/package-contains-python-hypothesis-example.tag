Tag: package-contains-python-hypothesis-example
Severity: warning
Check: files/names
Explanation: This package appears to contain the output of running a Python
 "Hypothesis" testsuite.
 .
 These are not useful in the binary package or to end-users. In addition,
 as they contain random/non-determinstic contents, they can affect the
 reproducibility of the package.
 .
 You can disable generation of these files by, for example:
 .
   export HYPOTHESIS&lowbar;DATABASE&lowbar;FILE = $(CURDIR)/debian/hypothesis
 .
   override&lowbar;dh&lowbar;auto&lowbar;clean:
           dh&lowbar;auto&lowbar;clean
           rm -rf $(CURDIR)/debian/hypothesis
