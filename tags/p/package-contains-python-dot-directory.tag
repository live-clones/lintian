Tag: package-contains-python-dot-directory
Severity: warning
Check: files/names
Explanation: The package contains files left over from a Python build
 process, such as cached output from <code>pytest</code>.
 .
 Users of your package probably do not need the files. Please rebuild
 your package with a newer version of <code>pybuild/dh-python</code>.
 Many of the files will disappear.
 .
 Usually, the files contain time-stamped data. They will prevent your
 package from being reproducible.
