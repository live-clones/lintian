Tag: maintainer-script-calls-chown-improperly
Severity: warning
Check: scripts
Renamed-From: maintainer-script-should-not-use-deprecated-chown-usage
Explanation: <code>chown user.group</code> is called in one of the maintainer
 scripts. The correct syntax is <code>chown user:group</code>. Using "." as a
 separator is still supported by the GNU tools, but it will fail as soon
 as a system uses the "." in user or group names.
See-Also: chown(1)
