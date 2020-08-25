Tag: quoted-placeholder-in-mailcap-entry
Severity: warning
Check: mailcap
Explanation: The <code>%s</code> placeholder in a mailcap entry is quoted. That is
 considered unsafe. Proper escaping should be left to the programs using
 the entry.
 .
 Please remove the single or double quotes around <code>%s</code>.
See-Also: Bug#33486,
 Bug#90483,
 Bug#745141,
 https://tools.ietf.org/rfc/rfc1524.txt,
 http://bugs.debian.org/745141#17,
 https://lists.debian.org/debian-user/2005/04/msg01185.html
