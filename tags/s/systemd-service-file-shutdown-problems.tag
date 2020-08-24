Tag: systemd-service-file-shutdown-problems
Severity: warning
Experimental: no
Check: systemd
See-Also: https://github.com/systemd/systemd/issues/11821
Explanation: The specified systemd <tt>.service</tt> file contains both
 <tt>DefaultDependencies=no</tt> and <tt>Conflicts=shutdown.target</tt>
 directives without <tt>Before=shutdown.target</tt>.
 .
 This can lead to problems during shutdown because the service may
 linger until the very end of shutdown sequence as nothing requests to
 stop it before (due to <tt>DefaultDependencies=no</tt>).
 .
 There is race condition between stopping units and systemd getting a
 request to exit the main loop, so it may proceed with shutdown before
 all pending stop jobs have been processed.
 .
 Please add <tt>Before=shutdown.target</tt>.
