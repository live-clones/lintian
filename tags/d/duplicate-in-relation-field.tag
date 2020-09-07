Tag: duplicate-in-relation-field
Severity: pedantic
Check: debian/control
Explanation: The given field in the <code>debian/control</code> file contains
 relations that are either identical or imply each other. The less
 restrictive one can be removed. This is done automatically by
 <code>dpkg-source</code> and <code>dpkg-gencontrol</code>, so this does not
 affect the generated package.
