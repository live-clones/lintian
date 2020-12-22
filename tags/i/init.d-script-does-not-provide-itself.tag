Tag: init.d-script-does-not-provide-itself
Severity: info
Check: init-d
Explanation: This <code>/etc/init.d</code> script indicates it provides one or
 more facilities, but none of the provided facilities match the name of
 the init script. In certain cases, it may be necessary to not follow
 that convention, but normally init scripts should always provide a
 facility matching the name of the init script.
See-Also: https://wiki.debian.org/LSBInitScripts
