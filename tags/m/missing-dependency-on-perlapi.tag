Tag: missing-dependency-on-perlapi
Severity: error
Check: binaries/prerequisites/perl
Explanation: This package includes a &ast;.so file in <code>/usr/lib/.../perl5</code>,
 normally indicating that it includes a binary Perl module. Binary Perl
 modules must depend on perlapi-$Config{version} (from the Config module).
 If the package is using debhelper, this problem is usually due to a
 missing dh&lowbar;perl call in <code>debian/rules</code> or a missing
 ${perl:Depends} substitution variable in the Depends line in
 <code>debian/control</code>.
See-Also: perl-policy 4.4.2
