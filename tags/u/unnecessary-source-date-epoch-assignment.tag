Tag: unnecessary-source-date-epoch-assignment
Severity: info
Check: debian/rules
Explanation: There is an assignment to a <code>SOURCE&lowbar;DATE&lowbar;EPOCH</code> variable in the
 <code>debian/rules</code> file.
 .
 As of dpkg 1.18.8, this is no longer necessary as dpkg exports this
 variable if it is not already set. However, you can also include
 <code>/usr/share/dpkg/pkg-info.mk</code> or <code>/usr/share/dpkg/default.mk</code>
 to ensure it is exported.
See-Also: https://reproducible-builds.org/specs/source-date-epoch/
