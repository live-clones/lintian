Tag: latest-changelog-entry-without-new-date
Severity: error
Check: debian/changelog
Explanation: The latest Debian changelog entry has either the same or even an
 older date as the entry before.
 .
 This can result in subtle bugs due to the <code>SOURCE&lowbar;DATE&lowbar;EPOCH</code>
 environment variable being the same between the older and newer
 versions.
