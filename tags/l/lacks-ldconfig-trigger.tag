Tag: lacks-ldconfig-trigger
Severity: error
Check: libraries/shared/trigger/ldconfig
Renamed-From:
 package-must-activate-ldconfig-trigger
Explanation: The package installs shared libraries in a directory controlled by
 the dynamic library loader. Therefore, the package must trigger libc's
 "ldconfig" trigger to ensure the ldconfig cache is updated.
 .
 If the package is using debhelper, <code>dh&lowbar;makeshlibs</code> should
 automatically discover this and add the trigger itself.
 Otherwise, please add <code>activate-noawait ldconfig</code> to the
 <code>triggers</code> file in the control member.
 .
 Note this tag may trigger for packages built with debhelper before
 version 9.20151004. In such case, a simple rebuild will often be
 sufficient to fix this issue.
See-Also:
 policy 8.1.1,
 https://lists.debian.org/debian-devel/2015/08/msg00412.html
