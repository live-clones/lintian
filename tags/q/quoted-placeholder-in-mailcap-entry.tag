Tag: quoted-placeholder-in-mailcap-entry
Severity: warning
Check: mailcap
Explanation: The <tt>%s</tt> placeholder in a mailcap entry is quoted. That is
 considered unsafe. Proper escaping should be left to the programs using
 the entry.
 .
 Please remove the single or double quotes around <tt>%s</tt>.
See-Also: #33486,
 #90483,
 #745141,
 https://tools.ietf.org/rfc/rfc1524.txt,
 http://bugs.debian.org/745141#17,
 https://lists.debian.org/debian-user/2005/04/msg01185.html
