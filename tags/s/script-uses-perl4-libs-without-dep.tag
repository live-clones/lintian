Tag: script-uses-perl4-libs-without-dep
Severity: warning
Check: languages/perl/perl4/prerequisites
Explanation: The named Perl script uses the named perl 4-era module,
 which is obsolete. Those libraries were deprecated in perl in 5.14,
 and will probably be removed from the core in perl 5.16.
 .
 Please remove the references to the module or add the prerequisite
 <code>libperl4-corelibs-perl | perl (&lt;&lt; 5.12.3-7)</code> to
 your package.
