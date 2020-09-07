Tag: dbus-system-service-wrong-name
Severity: error
Check: desktop/dbus
Explanation: The package contains a D-Bus system service whose filename
 does not match the <code>Name</code> field found in the file.
 This will not work, because dbus-daemon-launch-helper specifically
 looks for that filename, in order to keep system-level activation
 secure and predictable.
 .
 If you implement a session service whose well-known name is
 <code>com.example.MyService1</code>, and it should be service-activatable,
 you must provide
 <code>/usr/share/dbus-1/system-services/com.example.MyService1.service</code>.
