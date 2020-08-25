Tag: debian-rules-passes-version-info-to-dh_shlibdeps
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package has a call to
 <code>dh&lowbar;shlibdeps(1)</code> with the <code>--version-info</code> or
 <code>-V</code> option.
 .
 However, this has no effect on <code>dh&lowbar;shlibdeps</code>; you probably
 wanted to pass this option to <code>dh&lowbar;makeshlibs(1)</code> instead.
See-Also: dh_shlibdeps(1), dh_makeshlibs(1)
