Tag: built-using-field-on-arch-all-package
Severity: info
Check: debian/control/field/built-using
Explanation: The stanza for an installation package in <code>debian/control</code>
 declares a <code>Built-Using</code> field even though the package is declared as
 <code>Architecture: all</code>. That is incorrect.
 .
 The <code>Built-Using</code> field is only used architecture-specific packages.
 Please remove the <code>Built-Using</code> field from the indicated location.
