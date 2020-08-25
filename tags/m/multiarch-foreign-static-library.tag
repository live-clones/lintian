Tag: multiarch-foreign-static-library
Severity: error
Check: files/multi-arch
Explanation: The package is architecture-dependent, ships a static library in a
 public, architecture-dependent library search path and is marked
 <code>Multi-Arch: foreign</code>. A compiler will be unable to find this file,
 unless it is installed for a matching architecture, but the <code>foreign</code>
 marking says that the architecture should not matter.
 .
 Please remove the <code>Multi-Arch: foreign</code> stanza.
