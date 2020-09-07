Tag: trailing-whitespace
Severity: pedantic
Check: debian/trailing-whitespace
Renamed-From: file-contains-trailing-whitespace
Explanation: This file contains lines with trailing whitespace characters.
 .
 Whilst often harmless and unsightly, such extra whitespaces can also
 cause tools to interpret the whitespace characters literally. The
 tool <code>diff(1)</code> does not like them, either. They are best
 avoided.
 .
 Some of these problems can be hard to track down.
 .
 Whitespace at the end of lines may be removed with the following:
 .
  $ sed -i -e 's@[[:space:]]&ast;$@@g' debian/control debian/changelog
 .
 If you use Emacs, you can also use "M-x wh-cl" (whitespace-cleanup).
 .
 However, if you wish to only remove trailing spaces and leave trailing tabs
 (eg. for Makefiles), you can use the following code snippet:
 .
  $ sed -i -e 's@[ ]&ast;$@@g' debian/rules
 .
 To remove empty lines from the end of a file, you can use:
 .
  $ sed -i -e :a -e '/^\n&ast;$/{$d;N;};/\n$/ba' debian/rules
