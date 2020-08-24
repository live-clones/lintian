Tag: obsolete-relation-form-in-source
See-Also: policy 7.1
Severity: error
Check: debian/control
Explanation: The forms "&lt;" and "&gt;" mean "&lt;=" and "&gt;=", not "&lt;&lt;"
 and "&gt;&gt;" as one might expect. These forms were marked obsolete and
 must no longer be used. Use the longer forms instead.
