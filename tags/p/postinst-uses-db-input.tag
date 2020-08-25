Tag: postinst-uses-db-input
Severity: warning
Check: debian/debconf
Explanation: It is generally not a good idea for postinst scripts to use debconf
 commands like <code>db&lowbar;input</code>. Typically, they should restrict themselves
 to <code>db&lowbar;get</code> to request previously acquired information, and have the
 config script do the actual prompting.
