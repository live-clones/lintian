Tag: package-installs-packlist
Severity: error
Check: languages/perl
Explanation: Packages built using the perl MakeMaker package will have a file
 named .packlist in them. Those files are useless, and (in some cases)
 have the additional problem of creating an architecture-specific
 directory name in an architecture-independent package.
 .
 They can be suppressed by adding the following to <code>debian/rules</code>:
 .
   find debian/*pkg* -type f -name .packlist -delete
 .
 or by telling MakeMaker to use vendor install dirs; consult a recent
 version of Perl policy. Perl 5.6.0-12 or higher supports this.
See-Also: perl-policy 4.1
