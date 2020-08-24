Tag: extra-whitespace-around-name-in-changelog-trailer
Severity: warning
Check: nmu
Explanation: There is too much whitespace around the name in debian/changelog.
 .
 The format is:
   -- NAME &lt;EMAIL&gt;  DATE
 .
 Note that there must be exactly 1 space after the "--" and exactly
 2 spaces before the "DATE".
