Tag: package-contains-timestamped-gzip
Severity: warning
Check: files/compressed/gz
Explanation: The package contains a gzip-compressed file that has timestamps.
 Such files make the packages unreproducible, because their
 contents depend on the time when the package was built.
 .
 Please consider passing the "-n" flag to gzip to avoid this.
See-Also: https://wiki.debian.org/ReproducibleBuilds
