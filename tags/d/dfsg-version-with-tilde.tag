Tag: dfsg-version-with-tilde
Severity: warning
Check: fields/version
Explanation: The version number of this package contains "~dfsg", probably in a
 form like "1.0~dfsg-1".
 .
 Generally speaking, it is recommended to use "+dfsg" in most cases,
 but using ~dfsg has a merit in the following scenario:
   * Upstream: releases 1.0 but it has dfsg incompatible content
   * Debian: ship 1.0~dfsg-1 which excludes dfsg incompatible one
   * Upstream: repack 1.0 then release it as same version again
   * Debian: ship 1.0-1
 This is possible because it satisfy 1.0-1 > 1.0~dfsg-1.
 In contrast to ~dfsg, it is impossible by 1.0+dfsg-1 because
 it can not satisfy 1.0-1 > 1.0+dfsg-1. (Even though it should ask upstream
 to ship 1.1 instead of repack and ship 1.0 again in such a case, so we can
 just ship 1.1-1)
