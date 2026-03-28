Tag: maintainer-script-supports-ancient-package-version
Severity: info
Check: maintainer-scripts/ancient-version
Explanation: The named maintainer script appears to look for a package version
 that is older than the current <code>oldstable</code> release.
 .
 Please remove the check for that version. Such upgrades are not supported.
