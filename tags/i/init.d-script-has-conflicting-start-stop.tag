Tag: init.d-script-has-conflicting-start-stop
Severity: warning
Check: init-d
See-Also: https://wiki.debian.org/LSBInitScripts
Explanation: The given runlevel was included in both the Default-Start and
 Default-Stop keywords of the LSB keyword section of this
 <code>/etc/init.d</code> script. Since it doesn't make sense to both start
 and stop a service in the same runlevel, there is probably an error in
 one or the other of these keywords.
