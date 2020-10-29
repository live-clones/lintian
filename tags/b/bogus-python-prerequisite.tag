Tag: bogus-python-prerequisite
Severity: error
Check: languages/python/bogus-prerequisites
Experimental: yes
Explanation: This Python package declares an invalid prerequisite.
 For example, packages should not refer to any of the <code>what-is-python</code>
 packages in the source field for <code>Build-Depends</code>, or in the binary
 fields for <code>Depends</code> or <code>Recommends</code>.
See-Also:
 Bug#973011
