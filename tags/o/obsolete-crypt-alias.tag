Tag: obsolete-crypt-alias
Severity: error
Check: binaries/obsolete/crypt
Explanation: The listed ELF binary appears to use the C library function
  <code>fcrypt</code>, which is a less-portable alias for <code>crypt</code>.
  Programs that use this function cannot be linked against the
  <code>libcrypt.so</code> provided by glibc 2.28 and higher.
  .
  The program should be changed to use <code>crypt</code> instead.
  .
  A false positive for this check is possible if the binary expects
  the definition of <code>fcrypt</code> to come from some shared library
  other than <code>libcrypt.so</code>, *and* that shared library
  defines this function to do something other than hash passphrases.
  If this is the case it is appropriate to override this tag.
