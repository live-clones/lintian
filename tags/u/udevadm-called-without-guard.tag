Tag: udevadm-called-without-guard
Severity: warning
Check: scripts
Explanation: The specified maintainer script uses <code>set -e</code> but seems to
 call <code>udevadm(8)</code> without a conditional guard.
 .
 <code>udevadm</code> can exist but be non-functional (such as inside a
 chroot) and thus can result in package installation or upgrade failure
 if the call fails.
 .
 Please guard the return code of the call via wrapping it in a suitable
 <code>if</code> construct, appending <code>|| true</code> or depending on the
 <code>udev</code> package.
See-Also: Bug#890224, udevadm(8)
