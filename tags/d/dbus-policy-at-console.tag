Tag: dbus-policy-at-console
Severity: warning
Check: desktop/dbus
Explanation: The package contains D-Bus policy configuration that uses the
 deprecated <code>at&lowbar;console</code> condition to impose a different policy
 for users who are "logged in at the console" according to
 systemd-logind, ConsoleKit or similar APIs, such as:
 .
   &lt;policy context="default"&gt;
     &lt;deny send&lowbar;destination="com.example.PowerManagementDaemon"/&gt;
   &lt;/policy&gt;
   &lt;policy at&lowbar;console="true"&gt;
     &lt;allow send&lowbar;destination="com.example.PowerManagementDaemon"/&gt;
   &lt;/policy&gt;
 .
 The maintainers of D-Bus recommend that services should allow or deny
 method calls according to broad categories that are not typically altered
 by the system administrator (usually either "all users", or only root
 and/or a specified system user). If finer-grained authorization
 is required, the service should accept the method call message, then call
 out to PolicyKit to decide whether to honor the request. PolicyKit can
 use system-administrator-configurable policies to make that decision,
 including distinguishing between users who are "at the console" and
 those who are not.
See-Also: https://bugs.freedesktop.org/show_bug.cgi?id=39611
