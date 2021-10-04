Tag: outdated-relation-in-shlibs
Severity: warning
Check: debian/shlibs
Renamed-From:
 shlibs-uses-obsolete-relation
Explanation: The forms "&lt;" and "&gt;" mean "&lt;=" and "&gt;=", not "&lt;&lt;"
 and "&gt;&gt;" as one might expect. For that reason these forms are
 obsolete, and should not be used in new packages. Use the longer forms
 instead.
See-Also: policy 7.1
