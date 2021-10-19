Tag: maintscript-calls-ldconfig
Severity: warning
Check: maintainer-scripts/ldconfig
Explanation: The given maintainer script calls ldconfig. However, explicit
 calls in maintainer scripts should be replaced by a dpkg trigger.
 .
 Please replace the "ldconfig" call with an <code>activate-noawait
 ldconfig</code> trigger. With debhelper it is usually sufficient
 to simply add that line to <code>debian/&lt;package&gt;.triggers</code>.
 .
 If you use debhelper, this warning will appear if the package was
 compiled with debhelper before 9.20151004. Assuming all ldconfig
 invocations have been added by debhelper, this warning will
 disappear once the package is rebuilt with a newer version of
 debhelper.
See-Also: https://lists.debian.org/debian-devel/2015/08/msg00412.html

Screen: glibc/control/ldconfig
Advocates: Debian Lintian Maintainers <lintian-maint@debian.org>
Reason: The packages built from <code>glibc</code> (notably <code>libc-bin</code>)
 need to call ldconfig in order to implement the <code>ldconfig</code> trigger.
 .
 Transferred from the check.
