Tag: web-application-depends-on-apache2-data-package
Severity: warning
Check: apache2
Explanation: The package appears to be a web application but declares a package
 relation with <code>apache2-bin</code>, <code>apache2-data</code> or any of its
 transitional packages. However, web applications are rarely bound to a specific
 web server version. Thus, they should depend on <code>apache2</code> only instead.
 If a web application is actually tied to a particular binary version of the web
 server a dependency against the virtual <code>apache2-api-YYYYMMDD</code> package
 is more appropriate.
