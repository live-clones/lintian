Tag: file-in-usr-marked-as-conffile
Severity: error
Check: conffiles
See-Also: policy 10.7.2
Explanation: All configuration files must reside in <code>/etc</code>. Files below
 <code>/usr</code> may not be marked as conffiles since <code>/usr</code> might be
 mounted read-only. The local system administrator would therefore not
 have a chance to modify this configuration file.
