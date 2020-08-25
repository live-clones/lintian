Tag: example-wrong-path-for-interpreter
Severity: info
Check: scripts
Explanation: The interpreter used by this example script is installed at another
 location on Debian systems. Normally the path should be updated to match
 the Debian location.
 .
 Note that, as a particular exception, Debian Policy § 10.4 states that
 Perl scripts should use <code>/usr/bin/perl</code> directly and not
 <code>/usr/bin/env</code>, etc.
