Tag: package-installs-nonbinary-perl-in-usr-lib-perl5
Severity: warning
Check: languages/perl
Explanation: Architecture-independent Perl code should be placed in
 <code>/usr/share/perl5</code>, not <code>/usr/lib/.../perl5</code>
 unless there is at least one architecture-dependent file
 in the module.
See-Also: perl-policy 2.3
