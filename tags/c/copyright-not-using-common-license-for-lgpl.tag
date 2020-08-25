Tag: copyright-not-using-common-license-for-lgpl
Severity: error
Check: debian/copyright
Renamed-From: copyright-should-refer-to-common-license-file-for-lgpl
See-Also: policy 12.5
Explanation: The strings "GNU Lesser General Public License", "GNU Library
 General Public License", or "LGPL" appear in the copyright file for this
 package, but the copyright file does not reference
 <code>/usr/share/common-licenses</code> as the location of the LGPL on Debian
 systems.
 .
 If the copyright file must mention the LGPL for reasons other than stating
 the license of the package, please add a Lintian override.
