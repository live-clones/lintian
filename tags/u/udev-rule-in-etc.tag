Tag: udev-rule-in-etc
Severity: error
Check: udev
See-Also: Bug#559208
Explanation: This package ships a udev rule and installs it under
 <code>/etc/udev/rules.d</code>, which is reserved for user-installed files.
 The correct directory for system rules is <code>/lib/udev/rules.d</code>.
