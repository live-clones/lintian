Tag: unstripped-static-library
Severity: info
Check: binaries
Explanation: The package installs an unstripped static library.
 .
 Please note, that static libraries have to be stripped with the
 <tt>--strip-debug</tt> option. You will probably also want to
 use <tt>--remove-section=.comment --remove-section=.note</tt>
 to avoid the static-library-has-unneeded-section tag.
 .
 <tt>dh_strip</tt> (after debhelper/9.20150811) will do this
 automatically for you.
