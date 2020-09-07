Tag: debhelper-compatibility-level-not-a-number
Severity: error
Check: debhelper
Explanation: The debhelper compatibility level specified in <code>debian/rules</code>
 is not a number. If you're using make functions or other more complex
 methods to generate the compatibility level, write the output into
 <code>debian/compat</code> instead of setting DH&lowbar;COMPAT. The latter should
 be available for a user to override temporarily.
