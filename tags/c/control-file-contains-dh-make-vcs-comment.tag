Tag: control-file-contains-dh-make-vcs-comment
Severity: warning
Check: template/dh-make/control/vcs
Renamed-From:
 control-file-contains-dh_make-vcs-comment
Explanation: The control file contains <code>VCS-&ast;</code> lines that are
 commented out. They were most likely placed there by <code>dh&lowbar;make</code>.
 .
 If the URLs are valid, they should be uncommented. Otherwise, they should be
 removed.
