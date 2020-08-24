Tag: built-using-field-on-arch-all-package
Severity: info
Check: debian/control
Explanation: This package builds a binary arch:all package which incorrectly
 specifies a Built-Using control field.
 .
 <tt>Built-Using</tt> only applies to architecture-specific packages.
 .
 Please remove the <tt>Built-Using</tt> line from your package
 definition.
