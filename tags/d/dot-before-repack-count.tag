Tag: dot-before-repack-count
Severity: info
Check: fields/version/repack/count
Explanation: The source version contains a repack count that is prefaced by a dot,
 like <code>+dfsg.N</code>.
 .
 For proper version sorting, please use <code>+dfsgN</code> instead.
 .
 Please note, however, that a version containing the dot <code>+dfsg.N-1</code> (here
 with a Debian revision) should not change to <code>+dfsgN-1</code> (without the dot)
 for the same upstream release. That is because <code>1.0+dfsgN-1</code> always appears
 less recent than the original <code>1.0+dfsg.1-1</code>. Please consider the new
 format when upstream cuts the next release.
See-Also:
 https://lists.debian.org/debian-devel/2021/10/msg00026.html
