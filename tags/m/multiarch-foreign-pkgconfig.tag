Tag: multiarch-foreign-pkgconfig
Severity: error
Check: files/multi-arch
Explanation: The package is architecture-dependent, ships a pkg-config file in a
 public, architecture-dependent pkg-config search path and is marked
 <code>Multi-Arch: foreign</code>. pkg-config will be unable to find this file,
 unless it is installed for a matching architecture, but the <code>foreign</code>
 marking says that the architecture should not matter.
 .
 Please remove the <code>Multi-Arch: foreign</code> stanza.
