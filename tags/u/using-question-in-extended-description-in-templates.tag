Tag: using-question-in-extended-description-in-templates
Severity: warning
Check: debian/debconf
Explanation: The extended description of a debconf template should never include
 a question.
 .
 If this template is only used internally by the package and not displayed
 to the user, put "for internal use" in the short description.
See-Also: devref 6.5.3.2
