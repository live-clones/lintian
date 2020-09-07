Tag: example-interpreter-not-absolute
Severity: info
Check: scripts
Explanation: This example script uses a relative path to locate its interpreter.
 This path will be taken relative to the caller's current directory, not
 the script's, so a user will probably not be able to run the example
 without modification. This tag can also be caused by script headers like
 <code>#!@BASH@</code>, which usually mean that the examples were copied out
 of the source tree before proper Autoconf path substitution.
