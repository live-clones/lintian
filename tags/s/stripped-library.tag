Tag: stripped-library
Severity: error
Check: libraries/debug-symbols
Renamed-From:
 library-in-debug-or-profile-should-not-be-stripped
Explanation: Libraries in <code>.../lib/debug</code> or in
 <code>.../lib/profile</code> must not be stripped; this defeats the whole
 point of the separate library.
