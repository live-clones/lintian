Tag: init.d-script-missing-dependency-on-local_fs
Severity: error
Check: init.d
Explanation: The given init script seems to refer to <tt>/var</tt>, possibly
 using a file from there. Without a dependency on <tt>$local_fs</tt> in
 Required-Start or Required-Stop, as appropriate, the init script might be
 run before <tt>/var</tt> is mounted or after it's unmounted.
 .
 Using Should-Start or Should-Stop to declare the dependency is
 conceptually incorrect since the $local_fs facility is always
 available. Required-Start or Required-Stop should be used instead.
See-Also: https://wiki.debian.org/LSBInitScripts
