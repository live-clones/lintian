Tag: perl-module-uses-perl4-libs-without-dep
Severity: warning
Check: languages/perl
Explanation: This package includes perl modules using obsoleted perl 4-era
 libraries. These libraries have been deprecated in perl in 5.14, and
 are likely to be removed from the core in perl 5.16. Please either
 remove references to these libraries, or add a dependency on
 <code>libperl4-corelibs-perl | perl (&lt;&lt; 5.12.3-7)</code> to this package.
