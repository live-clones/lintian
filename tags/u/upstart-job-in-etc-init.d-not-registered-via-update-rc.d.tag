Tag: upstart-job-in-etc-init.d-not-registered-via-update-rc.d
Severity: warning
Check: init-d
Explanation: The package installs an upstart-job in <code>/etc/init.d</code>
 which is not registered in the <code>postinst</code> script. On
 non-upstart systems this is usually a bug, unless you omit the links
 intentionally for some reason or create the links some other way.
 .
 This tag should only be emitted for vendors that do not use upstart
 by default (such as Debian). If this tag is emitted by a vendor
 using upstart (e.g. Ubuntu), it may be a misconfiguration of their
 Lintian vendor profile.
