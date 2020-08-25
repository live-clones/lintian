Tag: dh-exec-useless-usage
Severity: info
Check: debhelper
Explanation: The package uses dh-exec for things it is not needed for.
 .
 This typically includes using ${DEB&lowbar;HOST&lowbar;MULTIARCH} in an install
 target where a wildcard would suffice. For example, if you had:
 .
  #! /usr/bin/dh-exec
  usr/lib/${DEB&lowbar;HOST&lowbar;MULTIARCH}
 .
 This could be replaced with the following in most cases, dropping the
 need for dh-exec:
 .
  usr/lib/&ast;
 .
 However, there may be other directories that match the wildcard,
 which one does not wish to install. In that case, this warning should
 be ignored or overridden.
