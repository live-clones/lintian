Tag: maintainer-script-calls-service
Severity: error
Check: scripts
Experimental: yes
Renamed-From: maintainer-script-should-not-use-service
Explanation: The maintainer script apparently runs the service command. This
 command is reserved for local administrators and must never be used
 by a Debian package.
 .
 Please replace with calls to <code>update-rc.d(8)</code> and
 <code>invoke-rc.d(8)</code>. If your package installs this service, this
 can be automated using <code>dh&lowbar;installinit(1)</code> or
 <code>dh&lowbar;installsystemd(1)</code>.
See-Also: policy 9.3.3
