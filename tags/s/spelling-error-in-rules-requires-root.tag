Tag: spelling-error-in-rules-requires-root
Severity: warning
Check: debian/control/field/rules-requires-root
Explanation: The sources attempt to declare a <code>Rules-Requires-Root</code> field
 but the field name is mispelled.
 .
 This tag was necessary because Debian uses a non-standard grammar. The field should
 be named <code>Rules-Require-Root</code> (with the verb in the singular).
 .
 For now, please rename the field to <code>Rules-Requires-Root</code>.
