Tag: debian-rules-calls-debhelper-in-odd-order
Severity: warning
Check: debian/rules
Explanation: One of the targets in the <code>debian/rules</code> file for this
 package calls debhelper programs in an odd order. Normally,
 dh_makeshlibs should be run before dh_shlibdeps or dh_installdeb, and
 dh_shlibdeps should be run before dh_gencontrol. dh_builddeb should be
 the last debhelper action when building the package, after any of the
 other programs mentioned. Calling these programs in the wrong order may
 cause incorrect or missing package files and metadata.
