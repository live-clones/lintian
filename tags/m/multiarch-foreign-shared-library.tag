Tag: multiarch-foreign-shared-library
Severity: error
Check: files/multi-arch
Explanation: The package is architecture-dependent, ships a shared library in
 a public library search path and is marked <code>Multi-Arch:
 foreign</code>. Typically, shared libraries are marked <code>Multi-Arch:
 same</code> when possible. Sometimes, private shared libraries are put
 into the public library search path to accommodate programs in the
 same package, but this package does not contain any programs.
 .
 Please remove the <code>Multi-Arch: foreign</code> stanza.
