Tag: init.d-script-starts-in-stop-runlevel
Severity: error
Check: init-d
Explanation: This <code>/etc/init.d</code> script specifies the 0 or 6 runlevels in
 Default-Start in its LSB keyword section. The 0 and 6 runlevels are
 meant to only stop services, not to start them. Even if the init script
 is doing something that isn't exactly stopping a service, the run-level
 should be listed in Default-Stop, not Default-Start, and the script
 should perform those actions when passed the <code>stop</code> argument.
