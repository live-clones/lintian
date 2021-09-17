Tag: elevated-privileges
Severity: warning
Check: files/permissions
Renamed-From:
 setuid-binary
 setgid-binary
 setuid-gid-binary
Explanation: This executable does not run with the identity of the user
 who executes it. It runs instead with its owner ID in the file system
 or with its group ID, or both.
 .
 This security-relevant setting is intentional for programs that
 regularly acquire elevated privileges, such as <code>/bin/su</code>,
 but can be a significant risk when it the setting is not intended.
 .
 Please override if needed.
