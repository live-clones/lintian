Tag: spare-manual-page
Severity: info
Check: documentation/manual
Renamed-From: manpage-without-executable
Explanation: Each manual page in <code>/usr/share/man</code> should have a reason to be
 there. This manual page does not appear to have a valid reason to be shipped.
 .
 For manual pages in sections 1 and 8, an executable (or a link to one) should
 exist. This check currently considers all installation packages created
 by the same sources, as long as they are present.
See-Also: policy 12.1, Bug#583125
