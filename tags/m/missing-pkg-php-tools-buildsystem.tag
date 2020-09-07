Tag: missing-pkg-php-tools-buildsystem
Severity: warning
Check: languages/php/pear
Explanation: The package uses pkg-php-tools but dh command is called without
 --buildsystem=phppear
 .
 pkg-php-tools build system is the recommended tool for building PHP PEAR
 packages. For more information, install it and read the included README.PEAR.
