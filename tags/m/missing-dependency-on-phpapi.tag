Tag: missing-dependency-on-phpapi
Severity: error
Check: binaries/prerequisites/php
Explanation: This package includes a &ast;.so file in <code>/usr/lib/phpN</code>
 (where N is a number representing the major PHP version), normally
 indicating that it includes a PHP extension. PHP extensions must
 depend on phpapi-$(php-configN --phpapi), without adding an
 alternative package with the OR operator.
 .
 This can usually be achieved by, for example, adding the following
 code to the binary-arch target of the rules file and adding
 <code>${php:Depends}</code> to the <code>Depends</code> field of the binary
 package shipping the extension:
 .
 echo "php:Depends=phpapi-$(php-config5 --phpapi)" &gt; debian/substvars
