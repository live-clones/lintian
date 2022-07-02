Tag: duplicate-short-description
Severity: info
Check: debian/control/field/description/duplicate
Explanation: The listed binary packages all share the same short description,
 i.e. the first line of the Description field in <code>debian/control</code>.
 .
 Please add a word or two, in parentheses if needed, to describe to users what
 they are installing.
 .
 It is not okay to rely solely on package naming conventions to indicate what
 is inside.
