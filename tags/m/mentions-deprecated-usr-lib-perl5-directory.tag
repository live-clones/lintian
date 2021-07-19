# Imported from pkg-perl-tools (named usr-lib-perl5-mentioned there)
Tag: mentions-deprecated-usr-lib-perl5-directory
Severity: error
Check: languages/perl/perl5
Experimental: yes
Explanation: As of Perl 5.20, the vendorarch directory is /usr/lib/&lt;triplet&gt;/perl5,
 but this package still uses usr/lib/perl5 in some of the files under debian/.
 Please replace that with the value of $Config{vendorarch} configuration
 parameter, e.g.
  $(shell perl -MConfig -wE'say substr($$Config{vendorarch},1)')
