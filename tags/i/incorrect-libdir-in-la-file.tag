Tag: incorrect-libdir-in-la-file
Severity: error
Check: build-systems/libtool/la-file
Explanation: The given .la file points to a libdir other than the path where it is
 installed. This can be caused by resetting <code>prefix</code> at make install
 time instead of using <code>DESTDIR</code>. The incorrect path will cause
 packages linking to this library using libtool to build incorrectly (adding
 incorrect paths to RPATH, for example).
