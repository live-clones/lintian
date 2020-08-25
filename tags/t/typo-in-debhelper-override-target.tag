Tag: typo-in-debhelper-override-target
Severity: warning
Check: debhelper
Explanation: The listed target in debian/rules is a likely misspelling or it is
 missing an underscore ("&lowbar;") between the <code>override&lowbar;dh</code>,
 <code>execute&lowbar;after&lowbar;dh</code> etc. and the command name.
 .
 This can result in (for example) a <code>override&lowbar;dh&lowbar;foo</code>-style target
 silently not being executed by <code>make</code>.
 .
 Implementation detail: The typo is detected by using "Levenshtein
 edit distance" so if the typo involve several characters Lintian may
 not detect it.
