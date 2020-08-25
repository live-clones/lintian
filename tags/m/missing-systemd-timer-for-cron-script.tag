Tag: missing-systemd-timer-for-cron-script
Severity: pedantic
Experimental: yes
Check: systemd
See-Also: systemd.timer(5), anacron(8)
Explanation: This package ships the specified cron script but does not ship a
 equivalent systemd <code>.timer</code> unit.
 .
 The "desktop" and "laptop" tasks no longer pull in anacron(8), the
 usual solution for desktop installations that are not running all the
 time.
 .
 Please consider shipping an equivalent <code>.timer</code> file for this
 script.
