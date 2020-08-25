Tag: invalid-potfiles-in
Severity: warning
Check: debian/po-debconf
Explanation: Errors were found in the <code>debian/po/POTFILES.in</code> file.
 .
 Please make sure that all strings marked for translation are in uniform
 encoding (say UTF-8) then prepend the following line to POTFILES.in and
 rerun intltool-update.
 .
  [encoding: UTF-8]
See-Also: Bug#849912, Bug#883653
