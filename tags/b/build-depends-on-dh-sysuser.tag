Tag: build-depends-on-dh-sysuser
Severity: error
Check: fields/package-relations
Explanation: The package build-depends on the <code>dh-sysuser</code> package.
 .
 The <code>dh-sysuser</code> package is specific to <code>runit</code> and
 must not be used as a generic mechanism for installing sysusers.d configs.
 .
 The canonical implementation for installing sysusers.d configs via debhelper
 is provided by <code>dh_installsysusers</code>, which is provided by
 <code>debhelper</code> since compat 13 and activated by build-depending on
 <code>dh-sequence-installsysusers</code>.
See-Also:
 dh_installsysusers(1),
 sysusers.d(5)
