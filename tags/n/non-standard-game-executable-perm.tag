Tag: non-standard-game-executable-perm
Severity: warning
Check: files/permissions
Explanation: The file is owned by the games group but is not mode 2755. If a
 game does not have to be setgid games, it should be owned by the root
 group like any other executable. This executable is either owned by the
 wrong group or is not setgid when it should be.
See-Also: policy 11.11
