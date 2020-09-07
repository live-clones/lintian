Tag: apache2-configuration-files-need-conf-suffix
Severity: error
Check: apache2
Explanation: The package is installing an Apache2 configuration but that file does not
 end with a '<code>.conf</code>' suffix. Starting with Apache2 2.4 all configuration
 files except module '<code>.load</code>' files need that suffix or are ignored otherwise.
