Tag: script-in-etc-init.d-not-registered-via-update-rc.d
Severity: warning
Check: init-d
Explanation: The package installs an <code>/etc/init.d</code> script which is
 not registered in the <code>postinst</code> script. This is usually a bug
 (such as omitting the <code>#DEBHELPER#</code> token) unless you omit the links
 intentionally for some reason or create the links some other way.
