Tag: binaries-have-file-conflict
Severity: warning
Check: group-checks
Experimental: no
Explanation: The binaries appears to have overlapping files without proper
 conflicts relation.
 .
 Note the check is completely based on the file index for the
 packages. Possible known false-positives include dpkg-diverts in
 maintainer scripts.
