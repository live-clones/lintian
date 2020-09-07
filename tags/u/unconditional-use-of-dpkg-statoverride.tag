Tag: unconditional-use-of-dpkg-statoverride
Severity: warning
Check: scripts
Explanation: The maintainer script appears to use <code>dpkg-statoverride --add</code>
 without a prior call to <code>dpkg-statoverride --list</code> to check the
 current status.
See-Also: policy 10.9.1
