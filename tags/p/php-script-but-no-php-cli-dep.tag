Tag: php-script-but-no-php-cli-dep
Severity: error
Check: scripts
Explanation: Packages with PHP scripts must depend on the php-cli package.
 Note that a dependency on a php-cgi package (such as php-cgi or php7.0-cgi)
 is needlessly strict and forces the user to install a package that isn't
 needed.
 .
 In some cases a weaker relationship, such as Suggests or Recommends, will
 be more appropriate.
 .
 If the script is not meant to be executable, but meant to be consumed by other
 programs or are reserved for specific use, the script should be made non-executable.
