Tag: debug-symbols-directly-in-usr-lib-debug
Severity: error
Check: binaries/debug-symbols/detached
Explanation: The given debugging symbols-only object is installed directly in
 <code>/usr/lib/debug</code>, although it should be installed in a
 subdirectory. For example, debug symbols of a binary in
 <code>/usr/bin</code> should be placed in <code>/usr/lib/debug/usr/bin</code>.
 gdb, when looking for debugging symbols, prepends <code>/usr/lib/debug</code>
 to whatever path it finds in the .gnu&lowbar;debuglink section, which when using
 dh&lowbar;strip(1) is either the path to your binary/library or a build-id based
 path.
