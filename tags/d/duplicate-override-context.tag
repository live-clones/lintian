Tag: duplicate-override-context
Severity: warning
Show-Always: yes
Check: lintian
Explanation: The given lines in the applicable override file refer to
 the same tag with the same context. It is redundant at best, and
 possibly indicates outdated overrides.
 .
 This condition is also flagged for renamed tags, for which it occurs
 perhaps more often as the overrides are adjusted for new tag names.
 .
 Please remove or adjust one of the overrides, whichever suits your
 purpose.
