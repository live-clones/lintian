Tag: package-uses-old-debhelper-compat-version
Severity: pedantic
Check: debhelper
Explanation: This package uses a debhelper compatibility level that is no
 longer recommended. Please consider using the recommended level.
 .
 For most packages, the best way to set the compatibility level is
 to specify <code>debhelper-compat (= X)</code> as a <code>Build-Depends</code>
 in <code>debian/control</code>. You can also use the <code>debian/compat</code>
 file or export DH&lowbar;COMPAT in <code>debian/rules</code>.
 .
 If no level is selected debhelper defaults to level 1, which is deprecated.
See-Also: debhelper(7)
