Tag: apache2-reverse-dependency-calls-invoke-rc.d
Severity: warning
Check: apache2
Explanation: The package is invoking apache2's init script in its maintainer script
 albeit it shouldn't do so. Reverse dependencies installing apache2
 configuration pieces should not restart the web server unconditionally in
 maintainer scripts. Instead they should be using apache2-maintscript-helper
 which correctly obeys local policies.
