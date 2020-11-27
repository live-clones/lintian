Tag: mismatched-override
Severity: warning
Show-Always: yes
Check: lintian
Explanation: The named tag could have been silenced but the context specified
 with the override did not match.
 .
 Lintian may now provide a different context for the tag, or something
 could have changed in a new version of your package. Either way,
 overrides work best when you require only little context.
 .
 You can use wildcards, such as &ast; or &quest; in the context to
 makes a match more likely.
 .
 Please remove or adjust the override, whichever suits your purpose.
