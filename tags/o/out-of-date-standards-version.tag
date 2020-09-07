Tag: out-of-date-standards-version
Severity: info
Check: fields/standards-version
See-Also: https://www.debian.org/doc/debian-policy/upgrading-checklist.html
Explanation: The source package refers to a Standards-Version older than the one
 that was current at the time the package was created (according to the
 timestamp of the latest <code>debian/changelog</code> entry). Please
 consider updating the package to current Policy and setting this control
 field appropriately.
 .
 If the package is already compliant with the current standards, you don't
 have to re-upload the package just to adjust the Standards-Version
 control field. However, please remember to update this field next time
 you upload the package.
 .
 See <code>/usr/share/doc/debian-policy/upgrading-checklist.txt.gz</code> in
 the debian-policy package for a summary of changes in newer versions of
 Policy.
