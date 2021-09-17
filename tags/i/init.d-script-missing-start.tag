Tag: init.d-script-missing-start
Severity: warning
Check: init-d
Explanation: The given <code>/etc/init.d</code> script indicates it should be
 started at one of the runlevels 2-5 but not at all of them. This is a
 mistake. The system administrators should be given the opportunity to
 customize the runlevels at their will.
See-Also: policy 9.3.3.1
