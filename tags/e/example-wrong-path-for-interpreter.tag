Tag: example-wrong-path-for-interpreter
Severity: info
Check: scripts
Explanation: The interpreter used by this example script is installed at another
 location on Debian systems. Normally the path should be updated to match
 the Debian location.
 .
 Note that, as a particular exception, Debian Policy § 10.4 states that
 Perl scripts should use <tt>/usr/bin/perl</tt> directly and not
 <tt>/usr/bin/env</tt>, etc.
