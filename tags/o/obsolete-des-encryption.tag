Tag: obsolete-des-encryption
Severity: error
Check: binaries/obsolete/crypt
Explanation: The listed ELF binary appears to use a C library function that
  performs DES encryption and/or decryption (<code>encrypt</code>,
  <code>encrypt&lowbar;r</code>, <code>setkey</code>, and/or <code>setkey&lowbar;r</code>).
  The DES block cipher can be broken by brute force on modern hardware,
  which makes any use of these functions insecure. Also, programs that
  use these functions cannot be linked against the <code>libcrypt.so</code>
  provided by glibc 2.28 and higher.
  .
  The program will need to be revised to use modern cryptographic
  primitives and protocols. Depending on how the program uses these
  functions, it may be necessary to continue using DES under some
  circumstances (e.g. for protocol compatibility, or to retain the
  ability to decrypt old data on disk) but this should be done using
  the DES functions in a modern cryptographic *library*
  (e.g. <code>libgcrypt</code>).
  .
  This is almost certainly an upstream bug, and should be addressed
  in coordination with the upstream maintainers of the software.
  .
  A false positive for this check is possible if the binary expects the
  definition of <code>encrypt</code>, <code>encrypt&lowbar;r</code>, <code>setkey</code>,
  and/or <code>setkey&lowbar;r</code> to come from some shared library other than
  <code>libcrypt.so</code>, *and* that shared library defines these
  functions to do something other than perform DES encryption. If this
  is the case it is appropriate to override this tag.
