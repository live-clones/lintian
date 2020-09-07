Tag: maintainer-script-empty
Severity: warning
Check: scripts
Explanation: The maintainer script doesn't seem to contain any code other than
 comments and boilerplate (set -e, exit statements, and the case statement
 to parse options). While this is harmless in most cases, it is probably
 not what you wanted, may mean the package will leave unnecessary files
 behind until purged, and may even lead to problems in rare situations
 where dpkg would fail if no maintainer script was present.
 .
 If the package currently doesn't need to do anything in this maintainer
 script, it shouldn't be included in the package.
