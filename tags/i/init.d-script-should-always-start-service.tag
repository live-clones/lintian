Tag: init.d-script-should-always-start-service
Severity: error
Check: init-d
Explanation: The specified file under <code>/etc/default/</code> includes a line
 such as <code>ENABLED=</code>, <code>DISABLED=</code>, <code>RUN=</code>, etc.
 .
 This is an older practice used so that the package's init script would
 not start the service until the local system administrator changed this
 value.
 .
 However, this hides from the underlying init system whether or not the
 daemon should actually be started leading to confusing behavior
 including <code>service package start</code> returning success without the
 service actually starting.
 .
 Please remove this mechanism and disable enabling the daemon on install
 via <code>dh&lowbar;installinit --no-enable</code> or move to automatically
 starting it.
See-Also: policy 9.3.3.1, update-rc.d(8), dh_installinit(1)
