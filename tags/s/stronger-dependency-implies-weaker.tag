Tag: stronger-dependency-implies-weaker
Severity: warning
Check: debian/control
See-Also: policy 7.2
Explanation: In the <tt>debian/control</tt> stanza for the given package, a
 stronger dependency field implies one of the dependencies in a weaker
 dependency field. In other words, the Depends field of the package
 requires that one of the packages listed in Recommends or Suggests be
 installed, or a package is listed in Recommends as well as Suggests.
 .
 Current versions of dpkg-gencontrol will silently fix this problem by
 removing the weaker dependency, but it may indicate a more subtle bug
 (misspelling or forgetting to remove the stronger dependency when it was
 moved to the weaker field).
