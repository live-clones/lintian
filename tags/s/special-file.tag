Tag: special-file
Severity: error
Check: files/special
Explanation: The package contains a so-called special file, like a device file.
 That is forbidden by policy.
 .
 If your program needs the device file, you should create it by calling
 <code>makedev</code> from the <code>postinst</code> maintainer script.
See-Also:
 debian-policy 10.6
