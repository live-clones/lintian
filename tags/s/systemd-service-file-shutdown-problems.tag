Tag: systemd-service-file-shutdown-problems
Severity: warning
Experimental: no
Check: systemd
See-Also: https://github.com/systemd/systemd/issues/11821
Explanation: The specified systemd <code>.service</code> file contains both
 <code>DefaultDependencies=no</code> and <code>Conflicts=shutdown.target</code>
 directives without <code>Before=shutdown.target</code>.
 .
 This can lead to problems during shutdown because the service may
 linger until the very end of shutdown sequence as nothing requests to
 stop it before (due to <code>DefaultDependencies=no</code>).
 .
 There is race condition between stopping units and systemd getting a
 request to exit the main loop, so it may proceed with shutdown before
 all pending stop jobs have been processed.
 .
 Please add <code>Before=shutdown.target</code>.
