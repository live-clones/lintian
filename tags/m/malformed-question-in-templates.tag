Tag: malformed-question-in-templates
Severity: warning
Check: debian/debconf
Explanation: The short description of a boolean debconf template should be
 phrased in the form of a question which should be kept short and should
 generally end with a question mark. Terse writing style is permitted and
 even encouraged if the question is rather long.
 .
 If this template is only used internally by the package and not displayed
 to the user, put "for internal use" in the short description.
See-Also: devref 6.5.4.2.2
