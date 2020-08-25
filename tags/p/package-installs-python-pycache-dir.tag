Tag: package-installs-python-pycache-dir
Severity: error
Check: languages/python
See-Also: python-policy 3.7
Explanation: The package installs a &lowbar;&lowbar;pycache&lowbar;&lowbar;
 directory, which is normally
 only used to store compiled Python source files. Compiled Python
 source files must not be included in the package, instead they
 should be generated at installation time in the postinst.
 .
 Note this tag is issues even if the directory is empty.
