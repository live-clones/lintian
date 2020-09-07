Tag: copyright-not-using-common-license-for-gpl
Severity: error
Check: debian/copyright
Renamed-From: copyright-should-refer-to-common-license-file-for-gpl
See-Also: policy 12.5
Explanation: The strings "GNU General Public License" or "GPL" appear in the
 copyright file for this package, but the copyright file does not
 reference <code>/usr/share/common-licenses</code> as the location of the GPL
 on Debian systems.
 .
 If the copyright file must mention the GPL for reasons other than stating
 the license of the package, please add a Lintian override.
