Tag: package-depends-on-multiple-tcl-versions
Severity: error
Check: fields/package-relations
Explanation: The package seems to declare several relations to a tcl version.
 This is not only sloppy but in the case of libraries, it may well break
 the runtime execution of programs.
