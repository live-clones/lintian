Tag: missing-dependency-on-perlapi
Severity: error
Check: binaries
See-Also: perl-policy 4.4.2
Explanation: This package includes a *.so file in <tt>/usr/lib/.../perl5</tt>,
 normally indicating that it includes a binary Perl module. Binary Perl
 modules must depend on perlapi-$Config{version} (from the Config module).
 If the package is using debhelper, this problem is usually due to a
 missing dh_perl call in <tt>debian/rules</tt> or a missing
 ${perl:Depends} substitution variable in the Depends line in
 <tt>debian/control</tt>.
