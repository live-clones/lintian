Tag: maintainer-script-has-unexpanded-debhelper-token
Severity: warning
Check: scripts
Explanation: Lintian has detected the presence of a #DEBHELPER# token in the
 listed maintainer/control script. By default, dh&lowbar;installdeb will remove
 the token when it makes a substitution in a script.
 .
 Please note that dh&lowbar;installdeb does *not* substitute the #DEBHELPER#
 token in udebs.
