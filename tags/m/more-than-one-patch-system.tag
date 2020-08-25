Tag: more-than-one-patch-system
Severity: warning
Check: debian/patches
Explanation: Either the build-dependencies list more than one patch system or the
 package uses the <code>3.0 (quilt)</code> source format but also has a
 dependency on <code>dpatch</code>. It's unlikely that you need both patch
 systems at the same time, and having multiple patch systems in play
 simultaneously can make understanding and modifying the source package
 unnecessarily complex.
