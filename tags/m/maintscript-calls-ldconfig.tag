Tag: maintscript-calls-ldconfig
Severity: warning
Check: maintainer-scripts/ldconfig
Explanation: The given maintainer script calls <code>ldconfig</code>,
 but such calls in maintainer scripts should be replaced instead by a
 <code>dpkg</code> trigger.
 .
 Please replace the <code>ldconfig</code> call with an <code>activate-noawait
 ldconfig</code> trigger. With Debhelper, it is usually sufficient
 to add that line to <code>debian/&lt;package&gt;.triggers</code>.
 .
 This warning may appear if the package was compiled with Debhelper older than
 version 9.20151004. Assuming all <code>ldconfig</code> invocations were added
 by Debhelper, this tag should disappear when the package is rebuilt with a
 newer version of Debhelper.
See-Also:
 https://lists.debian.org/debian-devel/2015/08/msg00412.html

Screen: glibc/control/ldconfig
Advocates: Debian Lintian Maintainers <lintian-maint@debian.org>
Reason: The packages built from <code>glibc</code> (notably <code>libc-bin</code>)
 need to call <code>ldconfig</code> in order to implement the <code>ldconfig</code> trigger.
 .
 Transferred from the check.
