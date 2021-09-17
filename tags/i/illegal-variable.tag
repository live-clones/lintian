Tag: illegal-variable
Severity: error
Check: debian/variables
Explanation: With debhelper compatibility level &gt;= 13 (and also
 <code>dh-exec</code> before it) several files in the
 <code>./debian</code> folder support the expansion of variables.
 Unfortunately, people sometimes confuse the
 <code>DEB&lowbar;BUILD&lowbar;&ast;</code>
 variables with the similarly-named
 <code>DEB&lowbar;HOST&lowbar;&ast;</code> variables.
 .
 Some conditions are difficult to detect but it is never correct
 to use <code>DEB&lowbar;BUILD&lowbar;MULTIARCH</code> in
 <code>debian/&ast;.install</code> or in
 <code>debian/&ast;.links</code>.
 .
 Please use <code>DEB&lowbar;HOST&lowbar;MULTIARCH</code> instead
 of <code>DEB&lowbar;BUILD&lowbar;MULTIARCH</code>.
See-Also:
 https://wiki.debian.org/Multiarch/Implementation#Recipes_for_converting_packages,
 Bug#983219
