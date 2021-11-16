Tag: dfsg-version-with-dfsg1
Severity: info
Check: fields/version
Explanation: The source version string start with +dfsgN like <code>+dfsg1</code>.
 It is probably in a form like <code>1.0+dfsg1-1</code>.
 .
 It's fairly rare to have to iterate on the repackaging many times.
 In most cases, <code>+dfsg-1</code> is enough.
 .
 If it needs to be iterated on, it should start with <code>+dfsgN-1</code>.
See-Also:
 https://lists.debian.org/debian-devel/2021/10/msg00026.html
