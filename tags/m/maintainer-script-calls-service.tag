Tag: maintainer-script-calls-service
Severity: error
Check: scripts
Experimental: yes
Renamed-From: maintainer-script-should-not-use-service
Explanation: The maintainer script apparently runs the service command. This
 command is reserved for local administrators and must never be used
 by a Debian package.
 .
 Please replace with calls to <tt>update-rc.d(8)</tt> and
 <tt>invoke-rc.d(8)</tt>. If your package installs this service, this
 can be automated using <tt>dh_installinit(1)</tt> or
 <tt>dh_installsystemd(1)</tt>.
See-Also: policy 9.3.3
