Tag: redundant-rules-requires-root-no-field
Severity: pedantic
Check: debian/control/field/rules-requires-root
Explanation: This package currently sets the <code>Rules-Requires-Root</code>
 field in the <code>debian/control</code> file to "no".
 .
 As of dpkg version 1.22.13, this field is set to "no" by default. As such,
 in this case the <code>Rules-Requires-Root</code> field is redundant and should be removed.
