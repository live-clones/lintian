Tag: library-not-linked-against-libc
Severity: error
Check: binaries/prerequisites
Explanation: The package installs a library which is not dynamically linked
 against libc.
 .
 It is theoretically possible to have a library which doesn't use any
 symbols from libc, but it is far more likely that this is a violation
 of the requirement that "shared libraries must be linked against all
 libraries that they use symbols from in the same way that binaries
 are".
See-Also:
 policy 10.2,
 Bug#698720
