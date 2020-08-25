Tag: apache2-module-does-not-ship-load-file
Severity: error
Check: apache2
Explanation: The package is an Apache2 HTTPD server module but does not ship a
 "<code>.load</code>" file or it was installed under an unexpected name. The load
 files in "<code>/etc/apache2/mods-available</code>" are required to interact with
 the server package to enable and disable the module and must match the module
 name without "<code>mod&lowbar;</code> prefix, e.g. <code>mod&lowbar;foo</code> must ship a load file
 named "<code>foo.load</code>".
