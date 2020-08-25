Tag: missing-dependency-on-numpy-abi
Severity: error
Check: binaries
Explanation: This package includes a Python extension module, which uses Numpy via its
 binary interface. Such packages must depend on python3-numpy-abi<i>N</i>.
 .
 If the package is using debhelper, this problem is usually due to a
 missing dh_numpy3 call in <code>debian/rules</code>.
See-Also: /usr/share/doc/python3-numpy/README.DebianMaints
