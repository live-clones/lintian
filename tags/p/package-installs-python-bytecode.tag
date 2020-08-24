Tag: package-installs-python-bytecode
Severity: error
Check: languages/python
See-Also: python-policy 3.7
Explanation: Compiled Python source files must not be included in the package.
 These files should be removed from the package and created at package
 installation time in the postinst.
