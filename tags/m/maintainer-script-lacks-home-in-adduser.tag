Tag: maintainer-script-lacks-home-in-adduser
Severity: error
Check: scripts
Renamed-From: maintainer-script-should-not-use-adduser-system-without-home
Explanation: The maintainer script apparently runs 'adduser --system'
 but hardcodes a path under '/home' for the '--home' option or
 does not use the '--home' option.
 .
 The FHS says: /home is a fairly standard concept, but it
 is clearly a site-specific filesystem. The setup will differ
 from host to host. Therefore, no program should rely on this
 location.
 .
 Note that passing --no-create-home alone does not solve the issue
 because home field of passwd file point to a non existing
 /home subdirectory. Please use
 <code>adduser --no-create-home --home /nonexistent</code> instead.
See-Also: fhs homeuserhomedirectories, adduser(8)
