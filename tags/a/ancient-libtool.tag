Tag: ancient-libtool
Severity: warning
Check: build-systems/autotools/libtool
Explanation: The referenced file seems to be from a libtool version older than
 1.5.2-2. This might lead to build errors on some newer architectures not
 known to this libtool.
 .
 Please ask your upstream maintainer to re-libtoolize the package or do it
 yourself if there is no active upstream. You will also need to run
 Autoconf to regenerate the configure script. Usually it is best to do
 this during the build by depending on autoconf, libtool, and automake if
 it is used, and then running:
 .
  autoreconf -i --force
 .
 before running configure. Depending on how old the package is, this may
 require additional modifications to <code>configure.ac</code> or
 <code>configure.in</code> or other work. If you do this during the build,
 determine which files it will add or update and be sure to remove those
 files in the clean target.
 .
 If you have fixed architecture-specific issues with minimal patches,
 rather than updating libtool, and verified that it builds correctly,
 please override this tag. Lintian will not be able to verify that.
