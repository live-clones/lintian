Tag: unconditional-use-of-dpkg-statoverride
Severity: warning
Check: maintainer-scripts/dpkg-statoverride
Explanation: The maintainer named script appears to use <code>dpkg-statoverride --add</code>
 without first calling <code>dpkg-statoverride --list</code> to check the current status.
See-Also:
 policy 10.9.1
