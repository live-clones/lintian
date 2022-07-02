Tag: systemd-service-file-uses-nobody-or-nogroup
Severity: warning
Check: systemd
Explanation: The specified <code>systemd</code> service file declares a <code>User=</code>
 or <code>Group=</code> that references <code>nobody</code> or <code>nogroup</code>.
 .
 The practice is discouraged. Starting with version 246, <code>systemd</code> version will
 log a warning about it.
See-Also:
 https://github.com/systemd/systemd/blob/v246/NEWS#L106-L113
