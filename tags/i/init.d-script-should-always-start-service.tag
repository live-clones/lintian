Tag: init.d-script-should-always-start-service
Severity: error
Check: init.d
Explanation: The specified file under <tt>/etc/default/</tt> includes a line
 such as <tt>ENABLED=</tt>, <tt>DISABLED=</tt>, <tt>RUN=</tt>, etc.
 .
 This is an older practice used so that the package's init script would
 not start the service until the local system administrator changed this
 value.
 .
 However, this hides from the underlying init system whether or not the
 daemon should actually be started leading to confusing behavior
 including <tt>service package start</tt> returning success without the
 service actually starting.
 .
 Please remove this mechanism and disable enabling the daemon on install
 via <tt>dh_installinit --no-enable</tt> or move to automatically
 starting it.
See-Also: policy 9.3.3.1, update-rc.d(8), dh_installinit(1)
