Tag: copyright-refers-to-deprecated-bsd-license-file
Severity: warning
Check: debian/copyright
See-Also: policy 12.5
Explanation: The copyright file refers to
 <code>/usr/share/common-licenses/BSD</code>. Due to the brevity of this
 license, the specificity of this copy to code whose copyright is held by
 the Regents of the University of California, and the frequency of minor
 wording changes in the license, its text should be included in the
 copyright file directly rather than referencing this file.
 .
 This file may be removed from a future version of base-files if
 references to it drop sufficiently.
