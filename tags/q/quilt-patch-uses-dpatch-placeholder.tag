Tag: quilt-patch-uses-dpatch-placeholder
Severity: info
Check: debian/patches/quilt
Explanation: This quilt patch file uses dpatch-specific placeholders like
 the <code>#!/bin/sh /usr/share/dpatch/dpatch-run</code> shebang or
 the <code>@DPATCH@</code> tag.
 .
 dpatch has been deprecated and the corresponding quilt patches should not use
 dpatch-specific syntax anymore.
