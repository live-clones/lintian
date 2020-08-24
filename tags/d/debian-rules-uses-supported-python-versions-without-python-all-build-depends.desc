Tag: debian-rules-uses-supported-python-versions-without-python-all-build-depends
Severity: warning
Check: debian/rules
Explanation: The package appears to use <tt>py3versions -s</tt> to determine
 the "supported" Python versions without specifying <tt>python3-all</tt>
 as a build-dependency.
 .
 With only the default version of Python installed, the package may
 build and test successfully but subsequently fail at runtime when
 another, non-default, Python version is present.
 .
 Please add <tt>python3-all</tt> as a build-dependency.
