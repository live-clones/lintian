Tag: directory-in-modprobe.d
Severity: error
Check: modprobe
See-Also: https://bugs.debian.org/1105784
Explanation: <code>modprobe.d</code> directories cannot contain
 directories themselves, as <code>kmod</code> does not support this.
 .
 This error may spawn from an incorrect use of <code>dh_install</code>.
 As such, it is recommended to use <code>dh_installmodules</code> instead,
 which prevents these kinds of issues.
