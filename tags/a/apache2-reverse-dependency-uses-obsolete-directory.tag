Tag: apache2-reverse-dependency-uses-obsolete-directory
Severity: warning
Check: apache2
Explanation: The package is installing a file into the obsolete
 <code>/etc/apache2/conf.d/</code> directory. This file is not read by the Apache2
 2.4 web server anymore. Instead <code>/etc/apache2/conf-available/</code> should be
 used.
