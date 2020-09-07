Tag: executable-is-not-world-readable
Severity: warning
Check: files/permissions
Explanation: All executables should be readable by any user. Since anyone can
 download the Debian package and obtain a copy of the executable, no
 security is gained by making the executable unreadable even for setuid
 binaries. If only members of a certain group may execute this file,
 remove execute permission for world, but leave read permission.
See-Also: policy 10.9
