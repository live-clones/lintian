Tag: build-depends-on-python-dev-with-no-arch-any
Severity: info
Check: fields/package-relations
Explanation: The given package appears to have a Python development package
 (<code>python3-dev</code>, <code>python3-all-dev</code> or
 <code>pythonX.Y-dev</code>) listed in its <code>Build-Depends</code> or
 <code>Build-Depends-Indep</code> fields, but only <code>Architecture: all</code>
 packages are built by this source package. Python applications and modules
 do not usually require those dev packages, so you should consider removing
 them in favour of <code>python3</code>, <code>python3-all</code>
 or <code>pythonX.Y</code>.
 .
 If you are building a Python extension instead, you should have
 development packages listed in <code>Build-Depends</code>, but normally there should
 be at least one <code>Architecture: any</code> package.
