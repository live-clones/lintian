Tag: built-using-field-on-arch-all-package
Severity: info
Check: debian/control
Explanation: This package builds a binary arch:all package which incorrectly
 specifies a Built-Using control field.
 .
 <code>Built-Using</code> only applies to architecture-specific packages.
 .
 Please remove the <code>Built-Using</code> line from your package
 definition.
