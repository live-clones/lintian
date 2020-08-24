Tag: undocumented-manual-page
Severity: warning
Check: documentation/manual
Renamed-From: link-to-undocumented-manpage
Explanation: Symbolic links to the undocumented(7) manual page may be provided
 if no manual page is available, but that is deprecated.
 .
 The lack of a manual page is still a bug, and if at all possible you
 should write one yourself.
 .
 For help with writing manual pages, refer to the Man-Page-HOWTO at
 http://www.schweikhardt.net/man_page_howto.html, the examples created
 by <tt>dh_make</tt>, or the
 <tt>/usr/share/doc/man-db/examples</tt> directory.
 If the package provides <tt>--help</tt> output, you might want to use
 the <tt>help2man</tt> utility to generate a simple manual page.
See-Also: policy 12.1
