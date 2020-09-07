Tag: init.d-script-does-not-source-init-functions
Severity: warning
Check: systemd
Explanation: The <code>/etc/init.d</code> script does not source
 <code>/lib/lsb/init-functions</code>. The <code>systemd</code> package provides
 <code>/lib/lsb/init-functions.d/40-systemd</code> to redirect
 <code>/etc/init.d/$script</code> calls to systemctl.
 .
 Please add a line like this to your <code>/etc/init.d</code> script:
 .
  . /lib/lsb/init-functions
