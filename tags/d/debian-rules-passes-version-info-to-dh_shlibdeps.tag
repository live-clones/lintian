Tag: debian-rules-passes-version-info-to-dh_shlibdeps
Severity: warning
Check: debian/rules
Explanation: The <tt>debian/rules</tt> file for this package has a call to
 <tt>dh_shlibdeps(1)</tt> with the <tt>--version-info</tt> or
 <tt>-V</tt> option.
 .
 However, this has no effect on <tt>dh_shlibdeps</tt>; you probably
 wanted to pass this option to <tt>dh_makeshlibs(1)</tt> instead.
See-Also: dh_shlibdeps(1), dh_makeshlibs(1)
