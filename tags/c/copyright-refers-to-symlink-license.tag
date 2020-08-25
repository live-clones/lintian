Tag: copyright-refers-to-symlink-license
Severity: pedantic
Check: debian/copyright
Explanation: The copyright file refers to the versionless symlink in
 <code>/usr/share/common-licenses</code> for the full text of the GPL, LGPL,
 or GFDL license. This symlink is updated to point to the latest version
 of the license when a new one is released. The package appears to allow
 relicensing under later versions of its license, so this is legally
 consistent, but it implies that Debian will relicense the package under
 later versions of those licenses as they're released. It is normally
 better to point to the version of the license the package references in
 its license statement.
 .
 For example, if the package says something like "you may redistribute it
 and/or modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation; either version 2, or (at your
 option) any later version", the <code>debian/copyright</code> file should
 refer to <code>/usr/share/common-licenses/GPL-2</code>, not <code>/GPL</code>.
 .
 For packages released under the same terms as Perl, Perl references the
 GPL version 1, so point to <code>/usr/share/common-licenses/GPL-1</code>.
