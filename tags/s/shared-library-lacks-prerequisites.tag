Tag: shared-library-lacks-prerequisites
Severity: warning
Check: binaries/prerequisites
Renamed-From:
 shared-lib-without-dependency-information
Explanation: The listed shared library doesn't include information about the
 other libraries against which it was linked.
 .
 More specifically, "<code>ldd foo.so</code>" should report such other
 libraries. In your case, it reports "statically linked".
 .
 The fix is to specify the libraries. One way to do so is to add
 something like "-lc" to the command-line options for "ld".
