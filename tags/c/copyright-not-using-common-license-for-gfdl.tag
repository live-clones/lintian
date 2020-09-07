Tag: copyright-not-using-common-license-for-gfdl
Severity: error
Check: debian/copyright
Renamed-From: copyright-should-refer-to-common-license-file-for-gfdl
See-Also: policy 12.5
Explanation: The strings "GNU Free Documentation License" or "GFDL" appear in the
 copyright file for this package, but the copyright file does not
 reference <code>/usr/share/common-licenses</code> as the location of the GFDL
 on Debian systems.
 .
 If the copyright file must mention the GFDL for reasons other than stating
 the license of the package, please add a Lintian override.
