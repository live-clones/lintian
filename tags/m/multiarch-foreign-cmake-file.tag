Tag: multiarch-foreign-cmake-file
Severity: error
Check: files/multi-arch
Explanation: The package is architecture-dependent, ships a cmake file in a public,
 architecture-dependent cmake search path and is marked <tt>Multi-Arch:
 foreign</tt>. CMake will be unable to find this file, unless it is installed
 for a matching architecture, but the <tt>foreign</tt> marking says that the
 architecture should not matter.
 .
 Please remove the <tt>Multi-Arch: foreign</tt> stanza.
