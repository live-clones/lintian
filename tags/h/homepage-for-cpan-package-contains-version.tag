Tag: homepage-for-cpan-package-contains-version
Severity: warning
Check: fields/homepage
Explanation: The Homepage field for this package points to CPAN and the URL
 includes the version. It's better to link to the unversioned CPAN page
 so that the URL doesn't have to be updated for each new release. For
 example, use:
 .
   http://search.cpan.org/dist/HTML-Template/
 .
 or
 .
   https://metacpan.org/release/HTML-Template/
 .
 not:
 .
   http://search.cpan.org/~samtregar/HTML-Template-2.9/
