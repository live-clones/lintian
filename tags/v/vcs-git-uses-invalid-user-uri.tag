Tag: vcs-git-uses-invalid-user-uri
Severity: warning
Check: fields/vcs
Explanation: The Vcs-Git field is pointing to a personal repository using
 a git://(git|anonscm).debian.org/~$LOGIN/$PRJ.git style URI. This is not
 recommended since the repository this points is not automatically updated
 when pushing to the personal repository. The recommended URI for anonymous
 access is https://anonscm.debian.org/git/users/$LOGIN/$PRJ.git.
