Tag: static-library-has-unneeded-section
Severity: info
Check: binaries
Explanation: The static library is stripped, but still contains a section
 that is not useful. You should call strip with
 <code>--remove-section=.comment --remove-section=.note</code> to remove the
 <code>.note</code> and <code>.comment</code> sections.
 .
 <code>dh_strip</code> (after debhelper/9.20150811) will do this
 automatically for you, but <code>install -s</code> will not because it calls
 strip without any arguments.
