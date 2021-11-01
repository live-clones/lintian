Tag: obsolete-relation-form-in-source
Severity: error
Check: debian/control/field/relation
Explanation: The short version restrictions <code>&lt;</code> and <code>&gt;</code>
 actually mean <code>&lt;=</code> and <code>&gt;=</code> (and not <code>&lt;&lt;</code>
 or <code>&gt;&gt;</code>, as one might expect).
 .
 The short forms are obsolete and no longer allowed. Please use the longer forms
 in the parentheses instead.
See-Also:
 policy 7.1
