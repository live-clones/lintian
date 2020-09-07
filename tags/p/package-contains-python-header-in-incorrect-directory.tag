Tag: package-contains-python-header-in-incorrect-directory
Severity: error
Check: files/names
Explanation: This package ships a header file such as
 <code>/usr/include/python3.7/foo/bar.h</code>. However,
 <code>/usr/include/python3.7</code> is a symlink to <code>python3.7m</code> in
 <code>libpython3.7-dev</code>.
 .
 This may result in silent file overwrites or, depending on the unpacking
 order (if <code>/usr/include/python3.7</code> is a directory), separating
 the headers into two independent trees.
 .
 These header files should be shipped in
 <code>/usr/include/python3.7m</code> instead.
