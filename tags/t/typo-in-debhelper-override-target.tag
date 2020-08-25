Tag: typo-in-debhelper-override-target
Severity: warning
Check: debhelper
Explanation: The listed target in debian/rules is a likely misspelling or it is
 missing an underscore ("_") between the <code>override_dh</code>,
 <code>execute_after_dh</code> etc. and the command name.
 .
 This can result in (for example) a <code>override_dh_foo</code>-style target
 silently not being executed by <code>make</code>.
 .
 Implementation detail: The typo is detected by using "Levenshtein
 edit distance" so if the typo involve several characters Lintian may
 not detect it.
