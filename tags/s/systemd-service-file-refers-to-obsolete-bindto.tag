Tag: systemd-service-file-refers-to-obsolete-bindto
Severity: warning
Check: systemd
Explanation: The systemd service file refers to the obsolete BindTo= option.
 .
 The <code>BindTo=</code> option has been deprecated in favour of
 <code>BindsTo=</code> which should be used instead.
See-Also: https://github.com/systemd/systemd/commit/7f2cddae09fd2579ae24434df577bb5e5a157d86
