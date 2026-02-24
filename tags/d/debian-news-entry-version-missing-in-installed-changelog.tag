Tag: debian-news-entry-version-missing-in-installed-changelog
Severity: warning
Check: debian/changelog
Explanation: The version number of the most recent <code>NEWS.Debian</code> entry
 does not match any of the version numbers in the installed changelog file for this
 package. This usually means the version in <code>NEWS.Debian</code> needs to
 be updated to match a change to package version that happened after the
 <code>NEWS.Debian</code> entry was written.
 .
 The installed changelog entries maybe trimmed in the interest of preserving size
 usually until the old-stable release. The NEWS entry might pre-date the same leading
 to this warning. If such is the case, the NEWS entry should be dropped or the version
 needs to be updated.
See-Also: Bug#954313
