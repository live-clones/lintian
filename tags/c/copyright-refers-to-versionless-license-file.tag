Tag: copyright-refers-to-versionless-license-file
Severity: warning
Check: debian/copyright
Explanation: The copyright file refers to the versionless symlink in
 <code>/usr/share/common-licenses</code> for the full text of the GPL, LGPL,
 or GFDL license, but the package does not appear to allow distribution
 under later versions of the license. This symlink will change with each
 release of a new version of the license and may therefore point to a
 different version than the package is released under.
 <code>debian/copyright</code> should instead refers to the specific version
 of the license that the package references.
 .
 For example, if the package says something like "you can redistribute it
 and/or modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation; version 2 dated June, 1991,"
 the <code>debian/copyright</code> file should refer to
 <code>/usr/share/common-licenses/GPL-2</code>, not <code>/GPL</code>.
