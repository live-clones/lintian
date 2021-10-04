Tag: specific-address-in-shared-library
Severity: error
Check: libraries/shared/relocation
Renamed-From:
 shlib-with-non-pic-code
Explanation: The listed shared libraries contain object code that was compiled 
 without -fPIC. All object code in shared libraries should be recompiled
 separately from the static libraries with the -fPIC option. 
 .
 Another common mistake that causes this problem is linking with 
 <code>gcc -Wl,-shared</code> instead of <code>gcc -shared</code>.
 .
 In some cases, exceptions to this rule are warranted. If this is such a
 case, follow the procedure outlined in Policy and then please document
 the exception by adding a Lintian override to this package.
 .
 To check whether a shared library has this problem, run <code>readelf
 -d</code> on the shared library. If a tag of type TEXTREL is present, the
 shared library contains non-PIC code.
See-Also:
 policy 10.2
