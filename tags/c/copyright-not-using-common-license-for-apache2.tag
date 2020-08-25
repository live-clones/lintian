Tag: copyright-not-using-common-license-for-apache2
Severity: error
Check: debian/copyright
Renamed-From: copyright-should-refer-to-common-license-file-for-apache-2
See-Also: policy 12.5
Explanation: The strings "Apache License, Version" or "Apache-2" appear in the
 copyright file for this package, but the copyright file does not
 reference <code>/usr/share/common-licenses</code> as the location of the
 Apache-2 on Debian systems.
 .
 If the copyright file must mention the Apache-2 for reasons other than
 stating the license of the package, please add a Lintian override.
