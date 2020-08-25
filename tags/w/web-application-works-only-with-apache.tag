Tag: web-application-works-only-with-apache
Severity: warning
Check: apache2
Renamed-From: web-application-should-not-depend-unconditionally-on-apache2
Explanation: The package appears to be a web application but declares a dependency
 against <code>apache2</code> without any alternative. Most web applications should
 work with any decent web server, thus such a package should be satisfied if any
 web server providing the virtual "<code>httpd</code>" package is installed. This
 can be accomplished by declaring a package relation in the form "<code>apache2 |
 httpd</code>".
