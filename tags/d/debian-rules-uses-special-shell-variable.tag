Tag: debian-rules-uses-special-shell-variable
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-underscore-variable
See-Also: policy 4.9, https://stackoverflow.com/a/27628164
Explanation: The rules file use the make variable $(&lowbar;).
 .
 According to Policy 4.9, 'invoking either of <code>make -f debian/rules
 &lt;...&gt;</code> or <code>./debian/rules
 &lt;args...&gt;</code>' must result in identical behavior'.
 One way to inadvertently violate this policy is to use the $&lowbar; variable.
 .
 If the rules file uses $(dir $(&lowbar;)) to discover the directory containing
 the source package (presumably in order to implement the get-orig-source
 target), please replace it by $(dir $(firstword $(MAKEFILE&lowbar;LIST))).
