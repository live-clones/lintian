Tag: license-problem-convert-utf-code
Severity: error
Check: cruft
Explanation: The following file source files include material under a
 non-free license from Unicode Inc. Therefore, it is
 not possible to ship this in main or contrib.
 .
 This license does not grant any permission
 to modify the files (thus failing DFSG#3). Moreover, the license grant
 seems to attempt to restrict use to "products supporting the Unicode
 Standard" (thus failing DFSG#6).
 .
 In this case a solution is to use libicu and to remove this code
 by repacking.
See-Also: Bug#823100
