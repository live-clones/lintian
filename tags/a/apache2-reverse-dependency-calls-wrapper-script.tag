Tag: apache2-reverse-dependency-calls-wrapper-script
Severity: warning
Check: apache2
Explanation: The package is calling an Apache2 configuration wrapper script (e.g.
 <tt>a2enmod</tt>, <tt>a2enconf</tt>, <tt>a2enconf</tt>, ...). Maintainer
 scripts should not be calling these scripts directly. To achieve a uniform and
 consolidated behavior these scripts should be invoked indirectly by using
 apache2-maintscript-helper.
