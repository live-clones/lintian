Tag: mismatched-override
Severity: warning
Show-Always: yes
Check: lintian
Explanation: The named tag would have been silenced except the context
 specified with the override did not match.
 .
 Lintian may now provide a different context for the tag, or something
 could have changed in a new version of your package. Either way,
 overrides work best when you require as little context as needed.
 .
 You can use wildcards, such as &ast; or &quest; in the context to
 make a match more likely.
 .
 Please remove or adjust the override.
