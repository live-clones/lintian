Tag: init.d-script-sourcing-without-test
Severity: error
Check: init-d
Explanation: The given <code>/etc/init.d</code> script seems to be sourcing an
 <code>/etc/default/</code> file without checking for its existence first.
 Files in <code>/etc/default/</code> can be deleted by the administrator at
 any time, and init scripts are required to handle the situation
 gracefully. For example:
 .
  [ -r /etc/default/foo ] && . /etc/default/foo
See-Also: policy 9.3.2
