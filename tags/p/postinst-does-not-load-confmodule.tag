Tag: postinst-does-not-load-confmodule
Severity: warning
Check: debian/debconf
Explanation: Even if your postinst does not involve debconf, you currently need to
 make sure it loads one of the debconf libraries. This will be changed in
 the future.
