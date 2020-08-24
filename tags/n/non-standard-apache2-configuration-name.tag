Tag: non-standard-apache2-configuration-name
Severity: warning
Check: apache2
Explanation: The package appears to be a web application which is installing a
 configuration file for the Apache2 HTTPD server. To avoid name clashes, any file
 installed to <tt>/etc/apache2/{sites,conf}-available</tt> should match the binary package
 name and must not start with <tt>local-</tt>.
