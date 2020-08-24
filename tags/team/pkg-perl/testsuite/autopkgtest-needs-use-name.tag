Tag: autopkgtest-needs-use-name
Severity: warning
Check: team/pkg-perl/testsuite
Name-Spaced: yes
Explanation: The pkg-perl use.t autopkgtest uses META.json or META.yml
 to extract the name of the main module in the package, which will
 then be checked with 'perl -w -M"module"' and expected to load ok
 and without warnings or other output. This package does not have
 content in META.{json,yml} and thus should provide the module name
 for use.t in debian/tests/pkg-perl/use-name.
 .
 See https://perl-team.pages.debian.net/autopkgtest.html
