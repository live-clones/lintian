Tag: maintainer-script-modifies-inetd-conf
Severity: error
Check: scripts
Explanation: The maintainer script modifies <tt>/etc/inetd.conf</tt> directly.
 This file must not be modified directly; instead, use the
 <tt>update-inetd</tt> script or the <tt>DebianNet.pm</tt> Perl module.
See-Also: policy 11.2
