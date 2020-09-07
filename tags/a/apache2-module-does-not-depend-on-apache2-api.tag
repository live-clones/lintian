Tag: apache2-module-does-not-depend-on-apache2-api
Severity: error
Check: apache2
Explanation: The package is an Apache2 HTTPD server module but does not declare a
 strong binary relation against the Apache2 server binary it links against. Modules
 must depend on the <code>apache2-api-YYYYMMNN</code> package provided as a virtual
 package by <code>apache2-bin</code>.
