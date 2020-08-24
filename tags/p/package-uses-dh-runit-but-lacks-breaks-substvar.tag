Tag: package-uses-dh-runit-but-lacks-breaks-substvar
Severity: warning
Check: debhelper
Explanation: This source package appears to use <tt>dh_runit(1)</tt> but the
 specified binary package does not define a <tt>Breaks:</tt> including
 the <tt>${runit:Breaks}</tt> substitution variable.
 .
 <tt>dh_runit(1)</tt> may generate scripts that make assumptions about
 the version of <tt>runit</tt> in use.
 .
 Please add the corresponding <tt>Breaks</tt> relation.
See-Also: dh_runit(1)
