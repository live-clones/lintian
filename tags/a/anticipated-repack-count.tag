Tag: anticipated-repack-count
Severity: info
Check: fields/version/repack/count
Explanation: The version contains the string <code>+dfsgN</code>
 where <code>N</code> is a low number as in <code>+dfsg1</code>.
 .
 Normally it is not necessary to repackage an upstream source package more than
 once. You can omit the repack count. In most cases <code>+dfsg-1</code> is
 enough.
 .
 If you really need to bump it, just go straight to <code>+dfsg2-1</code>.
See-Also:
 https://lists.debian.org/debian-devel/2021/10/msg00026.html
