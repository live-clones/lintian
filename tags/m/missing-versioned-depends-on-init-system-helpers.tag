Tag: missing-versioned-depends-on-init-system-helpers
Severity: warning
Check: scripts
See-Also: update.d(8), Bug#910593
Explanation: This package uses a command in the specified maintainer script
 but does not specify an appropriate minimum dependency on the
 <code>init-system-helpers</code> package. It may have been added to the
 package's <code>Build-Depends</code> instead of the corresponding binary
 package.
 .
 For example, the <code>defaults-disabled</code> option was added to
 <code>update-rc.d</code> in <code>init-system-helpers</code> version 1.50.
 .
 Please add a suitable <code>Depends:</code> to your <code>debian/control</code>
 file.
