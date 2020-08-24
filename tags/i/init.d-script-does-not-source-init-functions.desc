Tag: init.d-script-does-not-source-init-functions
Severity: warning
Check: systemd
Explanation: The <tt>/etc/init.d</tt> script does not source
 <tt>/lib/lsb/init-functions</tt>. The <tt>systemd</tt> package provides
 <tt>/lib/lsb/init-functions.d/40-systemd</tt> to redirect
 <tt>/etc/init.d/$script</tt> calls to systemctl.
 .
 Please add a line like this to your <tt>/etc/init.d</tt> script:
 .
  . /lib/lsb/init-functions
