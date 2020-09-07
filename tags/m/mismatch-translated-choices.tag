Tag: mismatch-translated-choices
Severity: error
Check: debian/debconf
Explanation: A "Choices:" field is a comma separated list, and translated
 "Choices:" fields must have the exact same number of elements. One
 of the translations does not follow this rule, you should contact the
 translator and request for a new translation where elements of "Choices:"
 fields have no embedded commas.
 .
 Cdebconf understands escaped commas in such fields, but packages
 outside the scope of debian-installer must not have them until they are
 also supported by debconf.
