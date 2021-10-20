Tag: maintainer-script-has-unexpanded-debhelper-token
Severity: warning
Check: build-systems/debhelper/maintainer-script/token
Explanation: The named maintainer script contains a <code>#DEBHELPER#</code>
 token. Normally, <code>dh&lowbar;installdeb</code> removes those tokens
 when it makes substitutions in a script.
 .
 Please note that <code>dh&lowbar;installdeb</code> does <strong>not</strong>
 substitute the <code>#DEBHELPER#</code> token in <code>udebs</code>.
