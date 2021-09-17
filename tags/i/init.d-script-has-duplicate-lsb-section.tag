Tag: init.d-script-has-duplicate-lsb-section
Severity: error
Check: init-d
See-Also: https://wiki.debian.org/LSBInitScripts
Explanation: This <code>/etc/init.d</code> script has more than one LSB keyword
 section. These sections start with <code>### BEGIN INIT INFO</code> and end
 with <code>### END INIT INFO</code>. There should be only one such section
 per init script.
