Tag: maintainer-script-changes-netbase
Severity: error
Check: scripts
Renamed-From: maintainer-script-should-not-modify-netbase-managed-file
Explanation: The maintainer script modifies at least one of the files
 <code>/etc/services</code>, <code>/etc/protocols</code>, and <code>/etc/rpc</code>,
 which are managed by the netbase package. Instead of doing this, please
 file a wishlist bug against netbase to have an appropriate entry added.
See-Also: policy 11.2
