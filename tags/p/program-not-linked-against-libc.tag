Tag: program-not-linked-against-libc
Severity: error
Check: binaries/prerequisites
Explanation: The package installs a binary which is not dynamically linked
 against libc.
 .
 It is theoretically possible to have a program which doesn't use any
 symbols from libc, but it is far more likely that this binary simply
 isn't linked correctly.
See-Also:
 Bug#698720
