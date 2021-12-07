Tag: dir-in-usr-local
Severity: error
Check: files/hierarchy/standard
Explanation: The package installs a directory in <code>/usr/local/...</code>. That is
 not allowed.
 .
 If you want to provide an empty directory in <code>/usr/local</code> for
 convenience of the local system administrator, please follow the rules
 in the policy manual (section 9.1.2), i.e. create the directories in
 the <code>postinst</code> maintainer script but do not fail if the operation
 is unsuccessful (for example, if <code>/usr/local</code> is mounted read-only).
See-Also:
 debian-policy 9.1.2
