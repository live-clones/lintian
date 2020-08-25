Tag: dbus-session-service-wrong-name
Severity: info
Check: desktop/dbus
Explanation: The package contains a D-Bus session service whose filename
 does not match the <code>Name</code> field found in the file.
 This makes it possible that two non-conflicting packages could
 provide the same service name with the same search-path priority
 (i.e. in the same directory). dbus-daemon will arbitrarily choose
 one of them, which is unlikely to be the desired result.
 .
 Best-practice is that if you implement a session service whose well-known
 name is <code>com.example.MyService1</code>, and it should be
 service-activatable, you should achieve that by packaging
 <code>/usr/share/dbus-1/services/com.example.MyService1.service</code>.
