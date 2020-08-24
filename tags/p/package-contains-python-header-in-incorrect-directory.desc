Tag: package-contains-python-header-in-incorrect-directory
Severity: error
Check: files/names
Explanation: This package ships a header file such as
 <tt>/usr/include/python3.7/foo/bar.h</tt>. However,
 <tt>/usr/include/python3.7</tt> is a symlink to <tt>python3.7m</tt> in
 <tt>libpython3.7-dev</tt>.
 .
 This may result in silent file overwrites or, depending on the unpacking
 order (if <tt>/usr/include/python3.7</tt> is a directory), separating
 the headers into two independent trees.
 .
 These header files should be shipped in
 <tt>/usr/include/python3.7m</tt> instead.
