Tag: hardening-no-pie
Severity: warning
Check: binaries/hardening
Explanation: This package provides an ELF executable that was not compiled
 as a position independent executable (PIE).
 .
 In Debian, since version 6.2.0-7 of the gcc-6 package GCC will
 compile ELF binaries with PIE by default. In most cases a simple
 rebuild will be sufficient to remove this tag.
 .
 PIE is required for fully enabling Address Space Layout
 Randomization (ASLR), which makes "Return-oriented" attacks more
 difficult.
 .
 Historically, PIE has been associated with noticeable performance
 overhead on i386. However, GCC &gt;= 5 has implemented an optimization
 that can reduce the overhead significantly.
 .
 If you use <code>dpkg-buildflags</code> with <code>hardening=+all,-pie</code>
 in <code>DEB&lowbar;BUILD&lowbar;MAINT&lowbar;OPTIONS</code>, remove the <code>-pie</code>.
See-Also: https://wiki.debian.org/Hardening,
 https://gcc.gnu.org/gcc-5/changes.html,
 https://software.intel.com/en-us/blogs/2014/12/26/new-optimizations-for-x86-in-upcoming-gcc-50-32bit-pic-mode
