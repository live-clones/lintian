Tag: stripped-library
Severity: error
Check: binaries
Renamed-From: library-in-debug-or-profile-should-not-be-stripped
Explanation: Libraries in <tt>.../lib/debug</tt> or in
 <tt>.../lib/profile</tt> must not be stripped; this defeats the whole
 point of the separate library.
