Tag: isdefault-flag-is-deprecated
Severity: warning
Check: debian/debconf
Explanation: The "isdefault" flag on debconf questions is deprecated as of debconf
 0.5.00, and has been replaced by "seen" with the inverse meaning. From
 debconf 0.5 onwards there should be very few reasons to use isdefault/seen
 anyway, as backing up works much better now. See
 /usr/share/doc/debconf-doc/changelog.gz for more information.
 .
 The misuse of isdefault often leads to questions being asked twice in one
 installation run, or, worse, on every upgrade. Please test your package
 carefully to make sure this does not happen.
