Tag: missing-call-to-update-fonts
Severity: warning
Check: scripts
Explanation: The maintainer script ships the specified X11 font but does not
 appear to call update-fonts-scale or update-fonts-dir in its postinst
 script.
 .
 If you are using dh&lowbar;installxfonts, add a dependency on ${misc:Depends}
 and dh&lowbar;installxfonts will take care of this for you.
See-Also: https://lists.debian.org/msgid-search/CAJqvfD-A1EPXxF_mS=_BaQ0FtqygVwRUf+23WqSqrkSmYgVAtA@mail.gmail.com
