Tag: dfsg-version-with-tilde
Severity: info
Check: fields/version/repack/tilde
Explanation: The source version string contains a tilde like <code>~dfsg</code>.
 It is probably in a form like <code>1.0~dfsg-1</code>.
 .
 Most people should use a plus sign instead, as in <code>+dfsg</code>. It will
 ensure proper version sorting.
 .
 We can think of two cases for which a tilde makes sense. First, upstream may release
 a tarball again using the same version, but with the offending files removed. The
 second case is when all DFSG concerns for a source tarball disappeared. In both cases,
 repacking is no longer necessary. We think both cases are rare.
See-Also:
 https://lists.debian.org/debian-devel/2021/10/msg00012.html,
 https://salsa.debian.org/lintian/lintian/-/merge_requests/379
