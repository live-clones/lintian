Tag: redundant-priority-optional-field
Severity: pedantic
Check: debian/control/field/priority
Explanation: This package currently sets the <code>Priority</code> field in the
 <code>debian/control</code> file to "optional".
 .
 As of dpkg version 1.22.13, this field is set to "optional" by default. As such,
 in this case the <code>Priority</code> field is redundant and should be removed.
