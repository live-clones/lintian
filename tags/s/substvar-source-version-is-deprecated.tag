Tag: substvar-source-version-is-deprecated
Severity: warning
Check: debian/version-substvars
Explanation: The package uses the now deprecated ${Source-Version} substvar,
 which has misleading semantics. Please switch to ${binary:Version} or
 ${source:Version} as appropriate (introduced in dpkg 1.13.19, released
 with etch). Support for ${Source-Version} may be removed from dpkg-dev
 in the future.
