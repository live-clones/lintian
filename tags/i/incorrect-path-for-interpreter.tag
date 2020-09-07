Tag: incorrect-path-for-interpreter
Severity: warning
Check: scripts
Explanation: The interpreter you used is installed at another location on Debian
 systems.
 .
 Whilst the script may work, it is in violation of Debian Policy. This
 may have been caused by usrmerge.
 .
 Note that, as a particular exception, Debian Policy § 10.4 states that
 Perl scripts should use <code>/usr/bin/perl</code> directly and not
 <code>/usr/bin/env</code>, etc.
See-Also: policy 10.4, https://wiki.debian.org/UsrMerge
