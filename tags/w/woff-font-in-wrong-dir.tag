Tag: woff-font-in-wrong-dir
Severity: warning
Check: fonts
Explanation: This package contains a WOFF or WOFF2 font (Web Open Font Format)
 that is installed outside of <code>/usr/share/fonts-fontname/woff/</code> or
 <code>/usr/share/fonts-fontname/woff2/</code>.
 .
 WOFF and WOFF2 fonts must not be installed to /usr/share/fonts/ as
 this causes problems with fontconfig.
See-Also: https://wiki.debian.org/Fonts/PackagingPolicy
