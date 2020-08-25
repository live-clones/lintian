Tag: maintainer-script-modifies-inetd-conf
Severity: error
Check: scripts
Explanation: The maintainer script modifies <code>/etc/inetd.conf</code> directly.
 This file must not be modified directly; instead, use the
 <code>update-inetd</code> script or the <code>DebianNet.pm</code> Perl module.
See-Also: policy 11.2
