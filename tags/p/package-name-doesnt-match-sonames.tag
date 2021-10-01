Tag: package-name-doesnt-match-sonames
Severity: warning
Check: libraries/shared/soname
Explanation: The package name of a library package should usually reflect
 the soname of the included library. The package name can determined
 from the library file name with the following code snippet:
 .
  $ objdump -p /path/to/libfoo-bar.so.1.2.3 | sed -n -e's/^[[:space:]]&ast;SONAME[[:space:]]&ast;//p' | \
      sed -r -e's/([0-9])\.so\./\1-/; s/\.so(\.|$)//; y/&lowbar;/-/; s/(.&ast;)/\L&/'
