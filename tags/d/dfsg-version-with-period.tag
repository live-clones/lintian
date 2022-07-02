Tag: dfsg-version-with-period
Severity: info
Check: fields/version/repack/period
Explanation: The version contains the string <code>.dfsg</code>.
 That versioning may harbor a subtle sorting issue, namely: <code>1.2.dfsg1</code>
 is a more recent version than <code>1.2.1</code>. It will therefore be difficult
 to find a nice version string for the next upstream release if it gains another
 dotted digit at the end.
 .
 It is better to use <code>+dfsg</code> instead. The plus sign <code>+</code> sorts
 before <code>.</code>, so the sorting that is usually desired can take place:
 .
   <code>1.2</code> &lt; <code>1.2+dfsg</code> &lt; <code>1.2.1</code>
