Tag: file-in-etc-modprobe.d
Severity: warning
Experimental: yes
Check: modprobe
Explanation: It is recommended to install modprobe files in
 <code>/usr/lib/modprobe.d</code> instead of <code>/etc/modprobe.d</code>.
 If moving a <code>.conf</code> file from the old directory to the new one,
 remember to also remove the lingering configuration file under
 <code>/etc</code>, possibly using <code>rm_conffile</code> in a
 <code>.maintscript</code> file as documented in
 <code>dh_installdeb(1)</code>.
 .
 This is done automatically by <code>dh_installmodules</code> starting with
 compatibility level 14.
