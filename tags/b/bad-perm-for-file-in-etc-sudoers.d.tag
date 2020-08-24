Tag: bad-perm-for-file-in-etc-sudoers.d
Severity: error
Check: files/permissions
Explanation: Files in /etc/sudoers.d/ must be 0440 or sudo will refuse to
 parse them.
See-Also: #588831, #576527
