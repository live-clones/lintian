Tag: redundant-installation-prerequisite
Severity: warning
Check: debian/control/prerequisite/redundant
Renamed-From:
 stronger-dependency-implies-weaker
Explanation: A stronger field for prerequisites in the <code>debian/control</code>
 file satisfies the named condition stated in a weaker field.
 .
 For example, you would see this tag when the <code>Depends</code> field
 already requires that a package which is also listed in <code>Recommends</code>
 or <code>Suggests</code> is installed. Or, a package could be listed in both
 <code>Recommends</code> as well as <code>Suggests</code>.
 .
 Current versions of <code>dpkg-gencontrol</code> will silently ignore the
 weaker field, but like anything unexpected it could indicate another oversight,
 such as a misspelling or having forgotten to remove the stronger prereguisite
 when the intent was to move it to a weaker field.
See-Also:
 policy 7.2
