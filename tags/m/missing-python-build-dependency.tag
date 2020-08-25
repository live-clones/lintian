Tag: missing-python-build-dependency
Severity: error
Check: debian/rules
See-Also: policy 4.2
Explanation: The package appears to use Python as part of its build process in
 <code>debian/rules</code> but doesn't depend on Python.
 .
 Normally, packages that use Python as part of the build process should
 build-depend on one of python, python-all, python-dev, python-all-dev,
 python2, or python2-dev depending on whether they support multiple
 versions of Python and whether they're building modules or only using
 Python as part of the package build process. Packages that depend on a
 specific version of Python may build-depend on the appropriate
 pythonX.Y or pythonX.Y-dev package instead.
