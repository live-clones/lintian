Tag: missing-call-to-update-fonts
Severity: warning
Check: desktop/x11/font/update
Explanation: The named maintainer script ships the specified X11 font but does
 not appear to call <code>update-fonts-scale</code> or <code>update-fonts-dir</code>
 in its <code>postinst</code> script.
 .
 If you are using <code>dh&lowbar;installxfonts</code>, add <code>${misc:Depends}</code>
 as a prerequisite and <code>dh&lowbar;installxfonts</code> will take care of it for you.
See-Also:
 https://lists.debian.org/msgid-search/CAJqvfD-A1EPXxF_mS=_BaQ0FtqygVwRUf+23WqSqrkSmYgVAtA@mail.gmail.com
