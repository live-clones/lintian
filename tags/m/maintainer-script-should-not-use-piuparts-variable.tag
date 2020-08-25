Tag: maintainer-script-should-not-use-piuparts-variable
Severity: warning
Check: scripts
See-Also: piuparts(1), https://piuparts.debian.org/doc/README.html
Explanation: The maintainer script appears to reference one of the
 <code>PIUPARTS_*</code> variables such as <code>PIUPARTS_TEST</code> or
 <code>PIUPARTS_PHASE</code>.
 .
 These variables are intended to be used by custom <code>piuparts(1)</code>
 scripts and not by maintainer scripts themselves.
 .
 Please remove the references to this variable.
