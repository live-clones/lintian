Tag: build-depends-on-python-dev-with-no-arch-any
Severity: info
Check: fields/package-relations
Explanation: The given package appears to have a Python development package
 (python3-dev, python3-all-dev or pythonX.Y-dev) listed in its Build-Depends
 or Build-Depends-Indep fields, but only "Architecture: all" packages are
 built by this source package. Python applications and modules do not
 usually require those dev packages, so you should consider removing them
 in favour of python3, python3-all or pythonX.Y.
 .
 If you are building a Python extension instead, you should have
 development packages listed in Build-Depends, but normally there should
 be at least one Architecture: any package.
