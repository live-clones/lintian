Tag: package-installs-java-bytecode
Severity: warning
Check: languages/java/bytecode
See-Also: java-policy 2
Explanation: Compiled Java source files must not be included in the package.
 This is likely due to a packaging mistake. These files should be
 removed from the installed package or included in <code>.jar</code>
 archives to save space.
