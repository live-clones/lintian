Tag: dbus-policy-excessively-broad
Severity: error
Check: desktop/dbus
Explanation: The package contains D-Bus policy configuration that
 matches broad classes of messages. This will cause strange side-effects,
 is almost certainly unintended, and is a probable security flaw.
 .
 For instance,
 .
   &lt;policy user="daemon"&gt;
     &lt;allow send&lowbar;type="method&lowbar;call"/&gt;
     &lt;allow send&lowbar;destination="com.example.Bees"/&gt;
   &lt;/policy&gt;
 .
 in any system bus policy file would allow the <code>daemon</code> user to send
 any method call to any service, including method calls which are meant to
 be restricted to root-only for security, such as
 <code>org.freedesktop.systemd1.Manager.StartTransientUnit</code>. (In addition,
 it allows that user to send any message to the <code>com.example.Bees</code>
 service.)
 .
 The intended policy for that particular example was probably more like
 .
   &lt;policy user="daemon"&gt;
     &lt;allow send&lowbar;type="method&lowbar;call" send&lowbar;destination="com.example.Bees"/&gt;
   &lt;/policy&gt;
 .
 which correctly allows method calls to that particular service only.
See-Also: http://www.openwall.com/lists/oss-security/2015/01/27/25
