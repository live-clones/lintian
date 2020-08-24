Tag: apache2-reverse-dependency-ships-file-in-not-allowed-directory
Severity: error
Check: apache2
Explanation: The package installs a piece of Apache2 configuration to
 <tt>/etc/apache2/{sites,mods,conf}-enabled</tt>. This is not allowed. Instead
 the respective <tt>/etc/apache2/{sites,mods,conf}-available</tt> counterparts
 must be used.
