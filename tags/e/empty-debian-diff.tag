Tag: empty-debian-diff
Severity: warning
Check: cruft
Explanation: The Debian diff of this non-native package appears to be completely
 empty. This usually indicates a mistake when generating the upstream
 tarball, or it may mean that this was intended to be a native package and
 was built non-native by mistake.
 .
 If the Debian packaging is maintained in conjunction with upstream, this
 may be intentional, but it's not recommended best practice. If the
 software is only for Debian, it should be a native package; otherwise,
 it's better to omit the <tt>debian</tt> directory from upstream releases
 and add it in the Debian diff. Otherwise, it can cause problems for some
 package updates in Debian (files can't be removed from the
 <tt>debian</tt> directory via the diff, for example).
