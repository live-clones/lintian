Tag: init.d-script-not-marked-as-conffile
Severity: warning
Check: init-d
See-Also: policy 9.3.2
Explanation: <code>/etc/init.d</code> scripts should be marked as conffiles.
 .
 This is usually an error, but the Policy allows for managing these files
 manually in maintainer scripts and Lintian cannot reliably detect that.
