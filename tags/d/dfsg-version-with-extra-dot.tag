Tag: dfsg-version-with-extra-dot
Severity: info
Check: fields/version/repack/count
Explanation: The source version string contains a extra dot like <code>+dfsg.</code>.
 It is probably in a form like <code>1.0+dfsg.2-1</code>.
 .
 In most cases, <code>+dfsg.N</code> is not used, instead, <code>+dfsgN</code> is used.
 It will ensure proper version sorting.
 .
 Note that +dfsg.N-1 can't be migrated to +dfsgN-1 in the same upstream version because
 1.0+dfsg.1-1 > 1.0+dfsgN-1 is always true, thus you need to migrate when upstream ships
 a newer version.
See-Also:
 https://lists.debian.org/debian-devel/2021/10/msg00026.html
