Tag: unused-override
Severity: info
Show-Always: yes
Check: lintian
Explanation: Your package specifies the named override but there were no
 tags that could have been silenced by it.
 .
 Maybe you fixed an underlying condition but forgot to remove the
 override. It is also possible that the Lintian maintainers fixed a
 false positive.
 .
 If the override is now unused, please remove it.
 .
 This tag is similar to <code>mismatched-override</code> except there a
 tag could have been silenced if the context had matched.
 .
 Sometimes, overrides end up not being used because a tag appears
 only on some architectures. In that case, overrides can be equipped
 with an architecture qualifier.
See-Also: lintian 2.4.3
