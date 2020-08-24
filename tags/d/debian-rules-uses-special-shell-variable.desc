Tag: debian-rules-uses-special-shell-variable
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-underscore-variable
See-Also: policy 4.9, https://stackoverflow.com/a/27628164
Explanation: The rules file use the make variable $(_).
 .
 According to Policy 4.9, 'invoking either of <tt>make -f debian/rules
 &lt;...&gt;</tt> or <tt>./debian/rules
 &lt;args...&gt;</tt>' must result in identical behavior'.
 One way to inadvertently violate this policy is to use the $_ variable.
 .
 If the rules file uses $(dir $(_)) to discover the directory containing
 the source package (presumably in order to implement the get-orig-source
 target), please replace it by $(dir $(firstword $(MAKEFILE_LIST))).
