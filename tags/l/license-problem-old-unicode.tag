Tag: license-problem-old-unicode
Severity: error
Check: cruft
Explanation: The following file includes material under an old, non-free license
 from Unicode Inc. Therefore, it is not possible to ship this in main or
 contrib.
 .
 The problematic license contains the text "Unicode, Inc. hereby grants the
 right to freely use the information supplied in this file in the creation of
 products supporting the Unicode Standard", which is non-free because it
 prohibits the use of the code in products that do not support the Unicode
 standard.
 .
 Unicode relicensed their files in 2004 with a DFSG license, but some programs
 that incorporated the code prior to that never updated their license text.
 There is information in the associated bug report about how projects have
 appropriately updated the licence.
See-Also: Bug#854209
