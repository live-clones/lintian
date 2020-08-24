Tag: unnecessary-source-date-epoch-assignment
Severity: info
Check: debian/rules
Explanation: There is an assignment to a <tt>SOURCE_DATE_EPOCH</tt> variable in the
 <tt>debian/rules</tt> file.
 .
 As of dpkg 1.18.8, this is no longer necessary as dpkg exports this
 variable if it is not already set. However, you can also include
 <tt>/usr/share/dpkg/pkg-info.mk</tt> or <tt>/usr/share/dpkg/default.mk</tt>
 to ensure it is exported.
See-Also: https://reproducible-builds.org/specs/source-date-epoch/
