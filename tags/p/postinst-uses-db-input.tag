Tag: postinst-uses-db-input
Severity: warning
Check: debian/debconf
Explanation: It is generally not a good idea for postinst scripts to use debconf
 commands like <code>db_input</code>. Typically, they should restrict themselves
 to <code>db_get</code> to request previously acquired information, and have the
 config script do the actual prompting.
