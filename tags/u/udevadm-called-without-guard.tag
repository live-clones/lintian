Tag: udevadm-called-without-guard
Severity: warning
Check: scripts
Explanation: The specified maintainer script uses <tt>set -e</tt> but seems to
 call <tt>udevadm(8)</tt> without a conditional guard.
 .
 <tt>udevadm</tt> can exist but be non-functional (such as inside a
 chroot) and thus can result in package installation or upgrade failure
 if the call fails.
 .
 Please guard the return code of the call via wrapping it in a suitable
 <tt>if</tt> construct, appending <tt>|| true</tt> or depending on the
 <tt>udev</tt> package.
See-Also: #890224, udevadm(8)
