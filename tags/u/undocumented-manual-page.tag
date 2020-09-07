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
 For help with writing manual pages, refer to the
 [Man-Page-HOWTO](http://www.schweikhardt.net/man_page_howto.html), the examples created
 by <code>dh&lowbar;make</code>, or the
 <code>/usr/share/doc/man-db/examples</code> directory.
 If the package provides <code>--help</code> output, you might want to use
 the <code>help2man</code> utility to generate a simple manual page.
See-Also: policy 12.1
