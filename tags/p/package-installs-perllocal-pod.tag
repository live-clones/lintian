Tag: package-installs-perllocal-pod
Severity: warning
Check: languages/perl
Explanation: This package installs a file <code>perllocal.pod</code>. Since that
 file is intended for local documentation, it is not likely that it is
 a good place for documentation supplied by a Debian package. In fact,
 installing this package will wipe out whatever local documentation
 existed there.
