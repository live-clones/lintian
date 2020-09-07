Tag: named-copyright-for-single-installable
Severity: warning
Check: debian/copyright
See-Also: policy 12.5
Explanation: Every package must include the file <code>/usr/share/doc/*pkg*/copyright</code>.
 A copy of this file should be in <code>debian/copyright</code> in the source package.
 .
 These sources ship a copyright file named according to debhelper convention
 <code>debian/$package.copyright</code> but build only one installable. Please move
 the copyright file to <code>debian/copyright</code>.
