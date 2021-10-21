Tag: hardening-no-fortify-functions
Severity: info
Check: binaries/hardening
Explanation: This package provides an ELF binary that lacks the use of fortified
 libc functions. Either there are no potentially unfortified functions
 called by any routines, all unfortified calls have already been fully
 validated at compile-time, or the package was not built with the default
 Debian compiler flags defined by <code>dpkg-buildflags</code>. If built using
 <code>dpkg-buildflags</code> directly, be sure to import <code>CPPFLAGS</code>.
 .
 NB: Due to false-positives, Lintian ignores some unprotected functions
 (e.g. memcpy).
See-Also: https://wiki.debian.org/Hardening, Bug#673112
