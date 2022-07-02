Tag: duplicate-override-context
Severity: warning
Show-Always: yes
Check: debian/lintian-overrides/duplicate
Explanation: The named lines in the given <code>override</code> file
 refer to the same tag with the same context. It is redundant, and
 may indicate outdated overrides.
 .
 This condition is also flagged for renamed tags, for which it occurs
 perhaps more often when the overrides are adjusted for new tag names.
 .
 Please remove one of the overrides or adjust in some way.
