Tag: dfsg-version-with-period
Severity: info
Check: fields/version
Explanation: The version number of this package contains ".dfsg", probably in a
 form like "1.2.dfsg1". There is a subtle sorting problem with this
 version method: 1.2.dfsg1 is considered a later version than 1.2.1. If
 upstream adds another level to its versioning, finding a good version
 number for the next upstream release will be awkward.
 .
 Upstream may never do this, in which case this isn't a problem, but it's
 normally better to use "+dfsg" instead (such as "1.2+dfsg1"). "+" sorts
 before ".", so 1.2 &lt; 1.2+dfsg1 &lt; 1.2.1 as normally desired.
