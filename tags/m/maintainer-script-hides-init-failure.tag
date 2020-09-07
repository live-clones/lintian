Tag: maintainer-script-hides-init-failure
Severity: warning
Check: scripts
Renamed-From: maintainer-script-should-not-hide-init-failure
Explanation: This script calls invoke-rc.d to run an init script but then, if the
 init script fails, exits successfully (using || exit 0). If the init
 script fails, the maintainer script should probably fail.
 .
 The most likely cause of this problem is that the package was built with
 a debhelper version suffering from Bug#337664 that inserted incorrect
 invoke-rc.d code in the generated maintainer script. The package needs to
 be reuploaded (could be bin-NMUd, no source changes needed).
