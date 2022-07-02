Tag: debian-rules-uses-special-shell-variable
Severity: warning
Check: debian/rules
Renamed-From:
 debian-rules-should-not-use-underscore-variable
Explanation: The rules file use the make variable $(&lowbar;).
 .
 According to Policy 4.9, 'invoking either of <code>make -f debian/rules
 &lt;...&gt;</code> or <code>./debian/rules
 &lt;args...&gt;</code>' must result in identical behavior'.
 The <code>$&lowbar;</code> variable is an easy way to to violate that rule
 unwittingly.
 .
 If the <code>rules</code> file uses <code>$(dir $(&lowbar;))</code> to
 discover the directory containing the source package (for example, in order
 to implement the <code>get-orig-source</code> target) please replace it
 with <code>$(dir $(firstword $(MAKEFILE&lowbar;LIST)))</code>.
See-Also:
 debian-policy 4.9,
 https://stackoverflow.com/a/27628164
