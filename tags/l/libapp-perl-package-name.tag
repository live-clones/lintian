Tag: libapp-perl-package-name
Severity: error
Check: application-not-library
Explanation: This package contains a program in $PATH and is named
 libapp-&ast;-perl which usually implies that the upstream project on CPAN
 is under the App:: hierarchy for applications. Instead of
 libfoo-bar-perl it should be named foo-bar.
 .
 People tend to skip library-like named packages when looking for
 applications in the package list and hence wouldn't notice this
 package.
See-Also: https://perl-team.pages.debian.net/policy.html#Package_Naming_Policy
