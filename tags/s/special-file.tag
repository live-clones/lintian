Tag: special-file
Severity: error
Check: files/special
Explanation: The package contains a *special* file (e.g., a device file).
 This is forbidden by current policy. If your program needs this device,
 you should create it by calling <code>makedev</code> from the postinst
 script.
See-Also: policy 10.6
