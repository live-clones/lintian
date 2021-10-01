Tag: unstripped-static-library
Severity: info
Check: libraries/static
Explanation: The package installs an unstripped static library.
 .
 Please note, that static libraries have to be stripped with the
 <code>--strip-debug</code> option. You will probably also want to
 use <code>--remove-section=.comment --remove-section=.note</code>
 to avoid the static-library-has-unneeded-section tag.
 .
 <code>dh&lowbar;strip</code> (after debhelper/9.20150811) will do this
 automatically for you.
