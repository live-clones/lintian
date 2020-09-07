Tag: non-standard-setuid-executable-perm
Severity: warning
Check: files/permissions
Explanation: The file is setuid or setgid and has a mode different from any of
 2755, 4755, 4754, or 6755. Any other permissions on setuid executables
 is probably a bug. In particular, removing root write privileges serves
 no purpose, group-writable setuid or setgid executables are probably bad
 ideas, and setgid executables that are not world-executable serve little
 purpose.
See-Also: policy 10.9
