Tag: maintainer-script-lacks-debhelper-token
Severity: warning
Check: debhelper
Explanation: This package is built using debhelper commands that may modify
 maintainer scripts, but the maintainer scripts do not contain
 the "#DEBHELPER#" token debhelper uses to modify them.
 .
 Adding the token to the scripts is recommended.
