Tag: composer-prerequisite
Severity: warning
Check: languages/php/composer
Explanation: A packaging relationship refers to the PHP composer.
 .
 The PHP <code>Composer</code> is a tool to install PHP packages similar to
 <code>pip</code> for Python and <code>npm</code> for Node.js. It should not
 be pulled in as a packaging relationship.
 .
 In Debian, the <code>composer</code> is dealt with in other ways, such as
 <code>dh_phpcomposer</code> from <code>pkg-php-tools</code> and
 <code>phpab</code>, which generates a static autoloader.
 .
 Maintainers of PHP-related packages may not be aware of all of the conventions
 since many such packages are maintained by individuals who are not associated
 with the PHP PEAR Maintainers team.
See-Also:
 dh_phpcomposer(1),
 phpab(1),
 https://getcomposer.org,
 https://en.wikipedia.org/wiki/Composer_(software),
 Bug#977150
