Tag: apache2-reverse-dependency-ships-file-in-not-allowed-directory
Severity: error
Check: apache2
Explanation: The package installs a piece of Apache2 configuration to
 <code>/etc/apache2/{sites,mods,conf}-enabled</code>. This is not allowed. Instead
 the respective <code>/etc/apache2/{sites,mods,conf}-available</code> counterparts
 must be used.
