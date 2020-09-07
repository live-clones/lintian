Tag: dbus-policy-without-send-destination
Severity: warning
Check: desktop/dbus
Explanation: The package contains D-Bus policy configuration that uses
 one of the <code>send&lowbar;&ast;</code> conditions, but does not specify a
 <code>send&lowbar;destination</code>, and is not specific to root.
 .
 Rules of the form
 .
   &lt;allow send&lowbar;interface="com.example.MyInterface"/&gt;
 .
 allow messages with the given interface to be sent to *any*
 service, not just the one installing the rule, which is rarely
 what was intended.
 .
 Similarly, on the system bus, rules of the form
 .
   &lt;deny send&lowbar;interface="com.example.MyInterface"/&gt;
 .
 are redundant with the system bus's default-deny policy, and have
 unintended effects on other services.
 .
 This check ignores rules of the form
 .
   &lt;policy user="root"&gt;
     &lt;allow ... /&gt;
   &lt;/policy&gt;
 .
 which are commonly used for the "agent" pattern seen in services like
 BlueZ and NetworkManager: a root-privileged daemon calls out to
 one or more per-user user interface agent processes with no specific
 name, so <code>send&lowbar;destination</code> is not easily applicable.
 However, such rules should still be made as specific as possible to
 avoid undesired side-effects.
See-Also: https://bugs.freedesktop.org/show_bug.cgi?id=18961,http://lists.freedesktop.org/archives/dbus/2008-February/009401.html
