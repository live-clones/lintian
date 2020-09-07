Tag: package-uses-dh-runit-but-lacks-breaks-substvar
Severity: warning
Check: debhelper
Explanation: This source package appears to use <code>dh&lowbar;runit(1)</code> but the
 specified binary package does not define a <code>Breaks:</code> including
 the <code>${runit:Breaks}</code> substitution variable.
 .
 <code>dh&lowbar;runit(1)</code> may generate scripts that make assumptions about
 the version of <code>runit</code> in use.
 .
 Please add the corresponding <code>Breaks</code> relation.
See-Also: dh_runit(1)
