Tag: debian-adds-editor-backup-file
Severity: warning
Check: cruft
Renamed-From:
 diff-contains-editor-backup-file
Explanation: The Debian diff or native package contains a file ending in
 <code>~</code> or of the form <code>.xxx.swp</code>, which is normally either an
 Emacs or vim backup file or a backup file created by programs such as
 <code>autoheader</code> or <code>debconf-updatepo</code>. This usually causes no
 harm, but it's messy and bloats the size of the Debian diff to no useful
 purpose.
