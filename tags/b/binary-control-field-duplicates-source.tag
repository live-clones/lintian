Tag: binary-control-field-duplicates-source
Severity: info
Check: debian/control
Explanation: In <code>debian/control</code>, this field for a binary package
 duplicates the value inherited from the source package paragraph. This
 doesn't hurt anything, but you may want to take advantage of the
 inheritance and set the value in only one place. It prevents missing
 duplicate places that need to be fixed if the value ever changes.
