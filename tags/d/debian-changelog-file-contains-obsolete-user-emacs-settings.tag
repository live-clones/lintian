Tag: debian-changelog-file-contains-obsolete-user-emacs-settings
Severity: warning
Check: debian/changelog
Explanation: The add-log-mailing-address variable is no longer honored in
 debian-changelog-mode, and should not appear in packages' changelog
 files. Instead, put something like this in your ~/.emacs:
 .
 (setq debian-changelog-mailing-address "userid@debian.org")
