Tag: outdated-relation-in-shlibs
See-Also: policy 7.1
Severity: warning
Check: shared-libs
Renamed-From: shlibs-uses-obsolete-relation
Explanation: The forms "&lt;" and "&gt;" mean "&lt;=" and "&gt;=", not "&lt;&lt;"
 and "&gt;&gt;" as one might expect. For that reason these forms are
 obsolete, and should not be used in new packages. Use the longer forms
 instead.
